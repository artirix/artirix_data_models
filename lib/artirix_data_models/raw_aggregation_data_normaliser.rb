module ArtirixDataModels
  class RawAggregationDataNormaliser

    FIND_BUCKETS = ->(_k, v, _o) { v.respond_to?(:key?) && v.key?(:buckets) }
    FIND_VALUE   = ->(_k, v, _o) { v.respond_to?(:key?) && v.key?(:value) }

    attr_reader :raw_aggs, :aggregations_factory, :list

    def initialize(aggregations_factory, raw_aggs)
      @aggregations_factory = aggregations_factory
      @raw_aggs             = raw_aggs
      @list                 = []
    end

    def normalise
      return [] unless raw_aggs.present?
      return raw_aggs if Array === raw_aggs

      normalise_hash(raw_aggs)

      list
    end

    alias_method :call, :normalise

    private

    def normalise_hash(hash)
      treat_buckets(hash)
      treat_values(hash)
    end

    def treat_buckets(hash)
      with_buckets_list = deep_locate hash, FIND_BUCKETS

      with_buckets_list.each do |with_buckets|
        with_buckets.each do |name, value|
          normalise_element(name, value)
        end
      end
    end

    def treat_values(hash)
      with_values_list = deep_locate hash, FIND_VALUE

      with_values_list.each do |with_values|
        with_values.each do |name, value|
          normalise_element(name, value)
        end
      end
    end

    def normalise_element(name, value)
      return unless Hash === value

      if value.key?(:buckets)
        add_normalised_buckets_element_to_list(name, value)
      elsif value.key?(:value)
        add_normalised_value_element_to_list(name, value)
      else
        normalise_hash(value)
      end
    end

    def add_normalised_buckets_element_to_list(name, value)
      buckets = value[:buckets].map do |raw_bucket|
        normalise_bucket(raw_bucket)
      end

      list << { name: name, buckets: buckets }
    end

    def add_normalised_value_element_to_list(name, value)
      list << { name: name, value: value[:value] }
    end

    def normalise_bucket(raw_bucket)
      basic_bucket(raw_bucket).tap do |bucket|
        nested_aggs           = nested_aggs_from(raw_bucket)
        bucket[:aggregations] = nested_aggs if nested_aggs.present?
      end
    end

    def basic_bucket(raw_bucket)
      name  = raw_bucket[:key_as_string] || raw_bucket[:key] || raw_bucket[:name]
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