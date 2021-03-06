require 'oj'

module ArtirixDataModels
  class EsCollection

    DEFAULT_SIZE                = 10
    CACHE_KEY_SECTION_SEPARATOR = '/'.freeze
    CACHE_KEY_RESULT_SEPARATOR  = '\\'.freeze

    def self.work_with_kaminari
      require 'kaminari'
      include KaminariEsCollection
    end

    def self.work_with_will_paginate
      require 'will_paginate'
      include WillPaginateEsCollection
    end

    EMPTY_RESPONSE = Oj.load(<<-JSON, symbol_keys: true)
{
   "took": 23,
   "timed_out": false,
   "_shards": {
      "total": 1,
      "successful": 1,
      "failed": 0
   },
   "hits": {
      "total": 0,
      "max_score": null,
      "hits": []
   }
}
    JSON

    def self.empty(model_class, from: 0, size: DEFAULT_SIZE)
      new model_class, response: EMPTY_RESPONSE, from: from, size: size
    end

    def self.from_array(array, total: nil, page_number: nil, per_page: nil)
      self.new(-> (x) { x }, response: {}).tap do |obj|
        total    ||= array.length
        per_page = per_page.to_i

        from  = 0
        size  = total
        slice = array

        if per_page > 0
          page_number = page_number.to_i
          page_number = 1 if page_number < 1

          from  = (page_number - 1) * per_page
          size  = per_page
          slice = array.drop(from).take(per_page)
        end

        obj.instance_variable_set(:@results, slice)
        obj.instance_variable_set(:@hits, { hits: slice })
        obj.instance_variable_set(:@total, total)
        obj.instance_variable_set(:@from, from)
        obj.instance_variable_set(:@size, size)
        obj.instance_variable_set(:@max_score, 1)
      end
    end

    include Enumerable
    include ArtirixDataModels::WithADMRegistry

    attr_reader :klass_or_factory, :response, :from, :size

    # @param klass_or_factory     [A Model Class|Callable] The model class or the Factory (callable object) to build the model
    # @param response             [Hash]  The full response returned from the DataLayer
    # @param from                 [Int]  requested offset (0 by default)
    # @param size                 [Int]  requested amount of hits (10 by default)
    # @param aggregations_factory [Int]  requested amount of hits (10 by default)
    #
    def initialize(klass_or_factory,
                   response:,
                   from: 0,
                   size: DEFAULT_SIZE,
                   adm_registry: nil,
                   adm_registry_loader: nil,
                   aggregations_factory: nil)

      set_adm_registry_and_loader adm_registry_loader, adm_registry

      @klass_or_factory     = klass_or_factory
      @response             = response
      @from                 = from
      @size                 = size
      @aggregations_factory = aggregations_factory
    end

    def aggregations_factory
      @aggregations_factory || adm_registry.get(:aggregations_factory)
    end

    # The number of total hits for a query
    #
    def total
      @total ||= hits[:total]
    end

    # The maximum score for a query
    #
    def max_score
      @max_score ||= hits[:max_score]
    end

    # The raw hits
    #
    def hits
      @hits ||= response[:hits]
    end

    def aggregations
      @aggregations ||= build_aggregations
    end

    def aggregation(name)
      n = name.to_sym
      aggregations.detect { |x| x.name == n }
    end

    def results
      @results ||= load_results
    end

    delegate :first, :drop, :take, :last, :[], :each, :present?, :blank?, :empty?, to: :results

    def data_hash(&block)
      block ||= :data_hash

      {
        size:         size,
        from:         from,
        total:        total,
        max_score:    max_score,
        aggregations: aggregations.map(&:data_hash),
        hits:         results.map(&block),
      }
    end

    def hits_data
      results.map(&:data_hash)
    end

    # Return the current page
    #
    def current_page
      from / size + 1 if from && size
    end

    def cache_key
      [
        total,
        size,
        from,
        results.map { |x| x.try(:cache_key) || x.to_s }.join(CACHE_KEY_RESULT_SEPARATOR)
      ].join(CACHE_KEY_SECTION_SEPARATOR)
    end

    def raw_aggregations_data
      response[:aggregations]
    end

    private
    def build_aggregations
      aggregations_factory.build_all_from_raw_data(raw_aggregations_data)
    end

    def load_results
      hits[:hits].map do |document|
        deserialize_document(document)
      end
    end

    def deserialize_document(document)
      info = info_from_document(document)

      model = if model_factory
                model_factory.call info
              elsif model_class
                model_class.new info
              else
                raise 'no model class, nor model factory'
              end
      complete_model model
    end

    def complete_model(model)
      if model
        adm_registry.register_model model
        model.try :set_adm_registry_loader, adm_registry_loader
      end

      model
    end

    def model_factory
      klass_or_factory.respond_to?(:call) ? klass_or_factory : nil
    end

    def model_class
      klass_or_factory.respond_to?(:new) ? klass_or_factory : nil
    end

    def info_from_document(document)
      document[:_source].merge _score: document[:_score],
                               _type:  document[:_type],
                               _index: document[:_index],
                               _id:    document[:_id]
    end

    module KaminariEsCollection
      extend ActiveSupport::Concern

      included do |base|
        base.__send__ :include, ::Kaminari::ConfigurationMethods
        base.__send__ :include, ::Kaminari::PageScopeMethods

        base.__send__ :paginates_per, DEFAULT_SIZE

        base.__send__ :delegate, :max_pages, to: :class

        base.__send__ :alias_method, :total_count, :total
        base.__send__ :alias_method, :limit_value, :size
        base.__send__ :alias_method, :per_page, :size
        base.__send__ :alias_method, :offset_value, :from
      end
    end

    module WillPaginateEsCollection
      extend ActiveSupport::Concern

      included do |base|
        base.__send__ :include, ::WillPaginate::CollectionMethods
        base.__send__ :delegate, :max_pages, to: :class

        base.__send__ :alias_method, :total_entries, :total
        base.__send__ :alias_method, :per_page, :size
        base.__send__ :alias_method, :offset, :from
      end

    end
  end
end
