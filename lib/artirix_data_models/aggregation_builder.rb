module ArtirixDataModels

  class AggregationBuilder
    attr_reader :aggregations_factory, :definition, :value_class, :aggregation_class

    def initialize(aggregations_factory:, definition:, aggregation_class: Aggregation, value_class: Aggregation::Value)
      @aggregations_factory = aggregations_factory
      @definition           = definition
      @aggregation_class    = aggregation_class
      @value_class          = value_class
    end

    def build
      aggregation_class.new agg_name, buckets
    end

    alias_method :call, :build

    private
    def buckets
      definition[:buckets].map do |bucket|
        build_bucket(bucket)
      end
    end

    def build_bucket(bucket)
      name        = bucket[:name]
      count       = bucket[:count]
      nested_aggs = nested_aggs_from(bucket)

      value_class.new agg_name, name, count, nested_aggs
    end

    def nested_aggs_from(bucket)
      raw_nested_aggs = bucket.fetch(:aggregations) { [] }

      raw_nested_aggs.map do |nested_agg|
        aggregations_factory.build_from_json nested_agg, value_class
      end
    end

    def agg_name
      definition[:name].to_sym
    end

  end
end