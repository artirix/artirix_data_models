module ArtirixDataModels
  class AggregationsFactory
    DEFAULT_COLLECTION_CLASS_NAME = ''.freeze

    # singleton instance
    def initialize
      @_loaders = Hash.new { |h, k| h[k] = {} }
      setup_config
    end

    def setup_config
      # To be Extended
    end

    def build_all_from_raw_data(raw, collection_class = nil)
      normalised = normalise_aggregations_data(raw)
      normalised.map { |definition| build_from_json definition, collection_class }
    end

    def build_from_json(aggregation, collection_class = nil)
      get_loader(aggregation[:name], collection_class).call aggregation
    end

    def get_loader(aggregation_name, collection_class)
      @_loaders[collection_class.to_s][aggregation_name.to_s] ||
        @_loaders[DEFAULT_COLLECTION_CLASS_NAME][aggregation_name.to_s] ||
        proc { |aggregation| aggregation_from_json aggregation }
    end

    def set_loader(aggregation_name, collection_class = nil, loader = nil, &block)
      if block
        @_loaders[collection_class.to_s][aggregation_name.to_s] = block
      elsif loader.respond_to? :call
        @_loaders[collection_class.to_s][aggregation_name.to_s] = loader
      else
        raise ArgumentError, "no block and no loader given for key #{key}"
      end
    end

    # static methods
    def self.set_loader(aggregation_name, collection_class, loader = nil, &block)
      instance.set_loader aggregation_name, collection_class, loader, &block
    end

    def self.build_from_json(aggregation_name, collection_class)
      instance.build_from_json aggregation_name, collection_class
    end

    private

    def deep_locate(object, callable)
      Hashie::Extensions::DeepLocate.deep_locate(callable, object).deep_dup
    end

    def normalise_aggregations_data(raw_aggs)
      return raw_aggs if Array === raw_aggs
      return [] unless raw_aggs.present?

      find_buckets = ->(_k, v, _o) { v.respond_to?(:key?) && v.key?(:buckets) }

      with_buckets_list = deep_locate raw_aggs, find_buckets

      with_buckets_list.reduce([]) do |list, with_buckets|
        with_buckets.each do |k, v|
          if Hash === v && v.key?(:buckets)
            buckets = v[:buckets].map do |raw_bucket|
              nested_aggs = normalise_aggregations_data(raw_bucket)

              name  = raw_bucket[:key] || raw_bucket[:name]
              count = raw_bucket[:doc_count] || raw_bucket[:count]

              { name: name, count: count }.tap do |bucket|
                bucket[:aggregations] = nested_aggs if nested_aggs.present?
              end
            end


            aggregation = { name: k, buckets: buckets }

            list << aggregation
          end
        end
        list
      end

    end

    def aggregation_from_json(definition, value_class = Aggregation::Value)
      agg_name = definition[:name].to_sym
      buckets  = definition[:buckets].map do |bucket|
        name        = bucket[:name]
        count       = bucket[:count]
        nested_aggs = bucket.fetch(:aggregations, []).map do |nested_agg|
          build_from_json nested_agg, value_class
        end

        value_class.new agg_name, name, count, nested_aggs
      end

      Aggregation.new agg_name, buckets
    end
  end
end