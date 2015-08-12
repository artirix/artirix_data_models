module ArtirixDataModels
  class AggregationsFactory
    DEFAULT_COLLECTION_CLASS_NAME = ''.freeze

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
      proc { |aggregation| Aggregation.from_json aggregation }
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

  end
end