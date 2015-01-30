module ArtirixDataModels
  class Aggregation < Struct.new(:name, :buckets)

    include Enumerable

    delegate :each, :empty?, to: :buckets

    def self.from_json(definition, value_class = Value)
      buckets = definition[:buckets].map do |bucket|
        value_class.new definition[:name].to_sym, bucket[:name], bucket[:count]
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
end