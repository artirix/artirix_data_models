module ArtirixDataModels
  class RawAggregationDataNormaliser

    FIND_BUCKETS = ->(_k, v, _o) { v.respond_to?(:key?) && v.key?(:buckets) }

    attr_reader :raw_aggs, :aggregations_factory

    def initialize(aggregations_factory, raw_aggs)
      @aggregations_factory = aggregations_factory
      @raw_aggs             = raw_aggs
    end

    def normalise
      return [] unless raw_aggs.present?
      return raw_aggs if Array === raw_aggs

      normalise_hash
    end

    alias_method :call, :normalise

    private

    def normalise_hash
      with_buckets_list = deep_locate raw_aggs, FIND_BUCKETS

      with_buckets_list.reduce([]) do |list, with_buckets|
        with_buckets.each do |name, value|
          add_normalised_element_to_list(list, name, value)
        end

        list
      end
    end

    def add_normalised_element_to_list(list, k, v)
      return unless Hash === v && v.key?(:buckets)

      buckets = v[:buckets].map do |raw_bucket|
        normalise_bucket(raw_bucket)
      end

      list << { name: k, buckets: buckets }
    end

    def normalise_bucket(raw_bucket)
      basic_bucket(raw_bucket).tap do |bucket|
        nested_aggs           = nested_aggs_from(raw_bucket)
        bucket[:aggregations] = nested_aggs if nested_aggs.present?
      end
    end

    def basic_bucket(raw_bucket)
      name  = raw_bucket[:key] || raw_bucket[:name]
      count = raw_bucket[:doc_count] || raw_bucket[:count]
      { name: name, count: count }
    end

    # aux
    def deep_locate(object, callable)
      Hashie::Extensions::DeepLocate.deep_locate(callable, object).deep_dup
    end

    def nested_aggs_from(raw_bucket)
      RawAggregationDataNormaliser.new(aggregations_factory, raw_bucket).normalise
    end
  end
end