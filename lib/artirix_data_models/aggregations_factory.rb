module ArtirixDataModels
  class AggregationsFactory
    DEFAULT_COLLECTION_CLASS_NAME = ''.freeze

    include ArtirixDataModels::WithDAORegistry

    # AGGREGATION CLASS BUILDING

    def self.sorted_aggregation_class_based_on_index_on(index_array)
      SortedBucketsAggregationClassFactory.build_class_based_on_index_on(index_array)
    end

    # FACTORY INSTANCE

    def initialize
      @_loaders = Hash.new { |h, k| h[k] = {} }
      setup_config
    end

    # SETUP AND CONFIG MANAGEMENT

    def setup_config
      # To be Extended
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

    def default_loader
      aggregations_factory = self
      proc { |definition|
        aggregations_factory.aggregation_from_json definition,
                                                   value_class: Aggregation::Value,
                                                   aggregation_class: Aggregation
      }
    end

    def get_loader(aggregation_name, collection_class)
      @_loaders[collection_class.to_s][aggregation_name.to_s] ||
        @_loaders[DEFAULT_COLLECTION_CLASS_NAME][aggregation_name.to_s] ||
        default_loader
    end

    # AGGREGATION BUILDING

    def build_from_json(aggregation, collection_class = nil)
      get_loader(aggregation[:name], collection_class).call aggregation
    end

    def build_all_from_raw_data(raw, collection_class = nil)
      normalised = normalise_aggregations_data(raw)
      normalised.map { |definition| build_from_json definition, collection_class }
    end

    def aggregation_from_json(definition, value_class: Aggregation::Value, aggregation_class: Aggregation)
      builder_params = {
        aggregations_factory: self,
        definition: definition,
        aggregation_class: aggregation_class,
        value_class: value_class,
      }

      AggregationBuilder.new(builder_params).build
    end

    private

    def normalise_aggregations_data(raw_aggs)
      RawAggregationDataNormaliser.new(self, raw_aggs).normalise
    end

    module SortedBucketsAggregationClassFactory
      def self.build_class_based_on_index_on(index_array)
        prepared_index_array = index_array.map { |key| SortedBucketsAggregationClassFactory.prepare_key(key) }
        sort_by_proc         = sort_by_index_on(prepared_index_array)

        Class.new(SortedBucketAggregationBase).tap do |klass|
          klass.sort_by_callable = sort_by_proc
        end
      end

      def self.prepare_key(key)
        key.to_s.strip.downcase
      end

      def self.sort_by_index_on(index_array)
        proc do |bucket|
          name = SortedBucketsAggregationClassFactory.prepare_key(bucket.name)

          found_index = index_array.index(name)

          if found_index.present?
            [0, found_index]
          else
            [1, 0]
          end
        end
      end

      class SortedBucketAggregationBase < ArtirixDataModels::Aggregation
        alias_method :unordered_buckets, :buckets

        def buckets
          @sorted_buckets ||= sort_buckets
        end

        def sort_buckets
          unordered_buckets.sort_by { |bucket| self.class.sort_by_callable.call(bucket) }
        end

        def self.sort_by_callable
          @sort_by_callable
        end

        def self.sort_by_callable=(callable = nil, &block)
          raise ArgumentError unless callable || block

          @sort_by_callable = callable || block
        end
      end

    end
  end
end