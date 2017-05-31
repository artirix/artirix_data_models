module ArtirixDataModels
  class RawAggregationDataNormaliser

    IS_NESTED_COUNTS = ->(v) { v.respond_to?(:key?) && v.key?(:doc_count) && v.keys.size == 1 }

    FIND_BUCKETS = ->(_k, v, _o) { v.respond_to?(:key?) && v.key?(:buckets) }
    FIND_VALUE   = ->(_k, v, _o) { v.respond_to?(:key?) && v.key?(:value) }
    FIND_COUNTS  = ->(_k, v, _o) do
      v.respond_to?(:key) &&
        v.key?(:doc_count) &&
        v.respond_to?(:values) &&
        v.values.any? { |x| IS_NESTED_COUNTS.call(x) }
    end

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
      treat_counts(hash)
    end

    def treat_buckets(hash)
      with_buckets_list = locate FIND_BUCKETS, hash

      with_buckets_list.each do |with_buckets|
        with_buckets.each do |name, value|
          normalise_element(name, value)
        end
      end
    end

    def treat_values(hash)
      with_values_list = locate FIND_VALUE, hash

      with_values_list.each do |with_values|
        with_values.each do |name, value|
          normalise_element(name, value)
        end
      end
    end

    def treat_counts(hash)
      with_values_list = locate FIND_COUNTS, hash
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
        nested = value.select { |_k, e| IS_NESTED_COUNTS.call e }
        if nested.present?
          add_normalised_nested_counts_to_list(name, nested)
        else
          normalise_hash(value)
        end
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

    def add_normalised_nested_counts_to_list(name, nested)
      buckets = nested.map do |bucket_name, nested_value|
        { name: bucket_name.to_s, count: nested_value[:doc_count] }
      end

      list << { name: name, buckets: buckets }

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
    def locate(callable, object)
      self.class.locate(callable, object).deep_dup
    end

    def nested_aggs_from(raw_bucket)
      RawAggregationDataNormaliser.new(aggregations_factory, raw_bucket).normalise
    end

    ###################################################
    # from former Hashie implementation (up to 3.4.x) #
    ###################################################

    def self.locate(comparator, object, result = [])
      if object.is_a?(::Enumerable)
        if object.any? { |value| match_comparator?(value, comparator, object) }
          result.push object
        else # DO NOT LOOK DEEPER ONCE FOUND IF THE VALUE FOUND IS A HASH (this will prevent us from properly recognising nested aggregations)!
          (object.respond_to?(:values) ? object.values : object.entries).each do |value|
            locate(comparator, value, result)
          end
        end
      end

      result
    end

    def self.match_comparator?(value, comparator, object)
      if object.is_a?(::Hash)
        key, value = value
      else
        key = nil
      end

      comparator.call(key, value, object)
    end
  end
end
