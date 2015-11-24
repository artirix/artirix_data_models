module ArtirixDataModels
  module CommonAggregation
    extend ActiveSupport::Concern

    def pretty_name
      I18n.t("aggregations.#{name.to_s.gsub('.', '_')}.name", default: default_pretty_name)
    end

    def default_pretty_name
      name
    end

    module ClassMethods
      def from_json(definition, value_class = Aggregation::Value)
        DAORegistry.aggregations_factory.aggregation_from_json(definition, value_class: value_class, aggregation_class: self)
      end
    end

  end

  class Aggregation < Struct.new(:name, :buckets)
    include CommonAggregation
    include Enumerable

    delegate :each, :empty?, to: :buckets

    def non_empty_buckets
      buckets.reject { |x| x.empty? }
    end

    def data_hash
      {
        name:    name,
        buckets: buckets.map(&:data_hash)
      }
    end

    def calculate_filtered(filtered_values = [])
      buckets.each do |b|
        b.filtered = filtered_values.include?(b.name)
      end

      self
    end

    def filtered_buckets
      buckets.select &:filtered?
    end

    def unfiltered_buckets
      buckets.reject &:filtered?
    end

    def filtered_first_buckets
      filtered_buckets + unfiltered_buckets
    end

    class MetricAggregation < Struct.new(:name, :value)
      include CommonAggregation

      def data_hash
        {
          name:  name,
          value: value
        }
      end

      def calculate_filtered(_filtered_values = [])
        # NOOP
        self
      end
    end

    class Value < Struct.new(:aggregation_name, :name, :count, :aggregations)
      attr_accessor :filtered

      def aggregations
        Array(super)
      end

      alias_method :nested_aggregations, :aggregations
      alias_method :nested_aggregations=, :aggregations=

      def pretty_name
        @pretty_name ||= load_pretty_name
      end

      def default_pretty_name
        name
      end

      def empty?
        count == 0
      end

      def aggregation(name)
        n = name.to_sym
        aggregations.detect { |x| x.name == n }
      end

      def data_hash
        basic_data_hash.tap do |h|
          if aggregations.present?
            h[:aggregations] = aggregations.map(&:data_hash)
          end
        end
      end

      def basic_data_hash
        {
          name:  name,
          count: count
        }
      end

      def mark_filtered
        @filtered = true
      end

      def mark_unfiltered
        @filtered = false
      end

      def filtered?
        !!@filtered
      end

      def pretty_name
        @pretty_name ||= super
      end

      private
      def load_pretty_name
        tranlsation_key = "aggregations.#{aggregation_name.to_s.gsub('.', '_')}.buckets.#{name.to_s.gsub('.', '_')}"
        I18n.t(tranlsation_key, default: default_pretty_name)
      end
    end
  end
end
