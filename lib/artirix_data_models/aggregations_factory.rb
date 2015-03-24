module ArtirixDataModels
  class AggregationsFactory
    DEFAULT_FACTORY               = ->(aggregation) { Aggregation.from_json aggregation }
    DEFAULT_COLLECTION_CLASS_NAME = ''.freeze

    # singleton instance
    def initialize
      @_loaders = Hash.new { |h, k| h[k] = {} }
      setup_config
    end

    def setup_config
      # To be Extended
    end

    def build_from_json(aggregation, collection_class = nil)
      get_loader(aggregation[:name], collection_class).call aggregation
    end

    def get_loader(aggregation_name, collection_class)
      @_loaders[collection_class.to_s][aggregation_name.to_s] ||
        @_loaders[DEFAULT_COLLECTION_CLASS_NAME][aggregation_name.to_s] ||
        DEFAULT_FACTORY
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
  end
end