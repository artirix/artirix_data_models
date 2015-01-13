require 'oj'

module ArtirixDataModels
  class EsCollection

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

    DEFAULT_SIZE = 10

    include Enumerable

    attr_reader :klass, :response, :from, :size

    # @param klass      [A Model Class] The model class
    # @param response   [Hash]  The full response returned from the DataLayer
    # @param from       [Int]  requested offset (0 by default)
    # @param size       [Int]  requested amount of hits (10 by default)
    #
    def initialize(klass, response:, from: 0, size: DEFAULT_SIZE)
      @klass    = klass
      @response = response
      @from     = from
      @size     = size
    end

    # The number of total hits for a query
    #
    def total
      hits[:total]
    end

    # The maximum score for a query
    #
    def max_score
      hits[:max_score]
    end

    # The raw hits
    #
    def hits
      response[:hits]
    end

    def aggregations
      @aggregations ||= response[:aggregations].to_a.map { |aggregation| Aggregation.from_json aggregation }
    end

    def aggregation(name)
      n = name.to_sym
      aggregations.detect { |x| x.name == n }
    end

    def results
      @results ||= load_results
    end

    delegate :each, :present?, :blank?, to: :results

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

    private
    def load_results
      hits[:hits].map do |document|
        deserialize_document(document)
      end
    end

    def deserialize_document(document)
      klass.new info_from_document(document)
    end

    def info_from_document(document)
      document[:_source].merge _score: document[:_score],
                               _type:  document[:_type],
                               _index: document[:_index],
                               _id:    document[:_id]
    end

    # AGGREGATIONS
    class Aggregation < Struct.new(:name, :buckets)

      include Enumerable

      delegate :each, :empty?, to: :buckets

      def self.from_json(definition)
        buckets = definition[:buckets].map do |bucket|
          Value.new definition[:name].to_sym, bucket[:name], bucket[:count]
        end

        new definition[:name].to_sym, buckets
      end

      def pretty_name
        I18n.t("aggregations.#{name.to_s.gsub('.', '_')}.name", default: default_pretty_name)
      end

      def default_pretty_name
        name
      end

      def non_empty_buckets
        buckets.reject { |x| x.empty? }
      end

      def data_hash
        {
          name:    name,
          buckets: buckets.map(&:data_hash)
        }
      end

      class Value < Struct.new(:aggregation_name, :name, :count)

        def pretty_name
          tranlsation_key = "aggregations.#{aggregation_name.to_s.gsub('.', '_')}.buckets.#{name.to_s.gsub('.', '_')}"
          I18n.t(tranlsation_key, default: default_pretty_name)
        end

        def default_pretty_name
          name
        end

        def empty?
          count == 0
        end

        def data_hash
          {
            name:  name,
            count: count
          }
        end
      end
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
