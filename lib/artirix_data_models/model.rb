# Responsibilities
# ================
#
# 1. ActiveModel compliant (to_param, valid?, save...)
# 2. Attributes (on initialise, getters and private setters)
# 3. Automatic timestamp attribute attributes definition (_timestamp)
# 4. Definition of Primary Key
# 5. Cache key (calculation of cache key based on minimum information)
# 6. Partial mode (reload, automatic reload when accessing an unavailable attribute)
#   6.1 partial mode - Reload with new data hash
#   6.2 partial mode - Check if in partial mode or in full mode
#   6.3 partial mode - reload using DAO
# 7. Rails Model Param based on Primary Key (for URLs and such)
#
module ArtirixDataModels
  module Model
    extend ActiveSupport::Concern

    included do
      include CompleteModel # by default
    end

    module Errors
      class ReadOnlyModelError < StandardError
      end
    end

    module CompleteModel
      extend ActiveSupport::Concern

      included do
        include ActiveModelCompliant
        include Attributes
        include Attributes::WithDefaultAttributes
        include PrimaryKey
        include WithDAO
        include CacheKey
        include PartialMode
      end
    end

    module OnlyData
      extend ActiveSupport::Concern

      included do
        include ActiveModelCompliant
        include Attributes
        include Attributes::OnlyData
      end
    end

    module WithBaseEntity
      extend ActiveSupport::Concern

      included do
        attr_accessor :base_entity
      end
    end

    module ActiveModelCompliant
      extend ActiveSupport::Concern

      included do
        include ActiveModel::Conversion
        extend ActiveModel::Naming
      end

      def save
        raise Errors::ReadOnlyModelError
      end

      def persisted?
        true
      end

      def valid?
        true
      end

      def new_record?
        false
      end

      def destroyed?
        false
      end

      def errors
        obj = Object.new

        def obj.[](key)
          []
        end

        def obj.full_messages()
          []
        end

        obj
      end
    end

    module Attributes
      extend ActiveSupport::Concern

      included do
        include KeywordInit
      end

      def self.direct_getter_method_name(attribute)
        "_get_#{attribute}"
      end

      def data_hash
        Hash[self.class.all_defined_attributes.map { |at| [at, send(Attributes.direct_getter_method_name(at))] }]
      end

      def compact_data_hash
        data_hash.reject { |_, v| v.nil? }
      end

      def inspect_with_tab(tab_level = 0)
        insp = data_hash.map do |at, val|
          v   = val.try(:inspect_with_tab, tab_level + 1) || val.inspect
          tab = ' ' * tab_level * 4
          "#{tab} - #{at}: #{v}"
        end
        "#<#{self.class} \n#{insp.join("\n")}>"
      end

      def inspect
        inspect_with_tab 1
      end

      module ClassMethods
        def attribute(*attributes)
          attributes.each { |attribute| _define_attribute attribute }
        end

        def defined_attributes
          @attribute_list ||= []
        end

        # deal with model inheritance

        def all_defined_attributes
          parent_defined_attributes_list + defined_attributes
        end

        attr_writer :parent_defined_attributes_list

        def parent_defined_attributes_list
          @parent_defined_attributes_list || []
        end

        def inherited(child_class)
          child_class.parent_defined_attributes_list = all_defined_attributes
        end

        private
        def _define_attribute(attribute)
          at = attribute.to_sym
          _define_getter(at)
          _define_presence(at)
          _define_writer(at)

          defined_attributes << at
        end

        def _define_writer(attribute)
          attr_writer attribute
          writer = "#{attribute}="
          private writer
        end

        def _define_presence(attribute)
          presence_method = "#{attribute}?"
          define_method presence_method do
            send(attribute).present?
          end
        end

        def _define_getter(attribute)
          variable_name = "@#{attribute}"
          dir_get_name  = Attributes.direct_getter_method_name(attribute)

          define_method dir_get_name do
            instance_variable_get variable_name
          end

          define_method(attribute) do
            val = send dir_get_name
            if val.nil?
              nil_attribute(attribute)
            else
              val
            end
          end
        end
      end

      module OnlyData
        # return nil as it is, we do not have DAO for an OnlyData model
        def nil_attribute(_)
          nil
        end
      end

      module WithDefaultAttributes
        extend ActiveSupport::Concern

        included do
          attribute :_timestamp
          attribute :_score
          attribute :_type
          attribute :_index
          attribute :_id
        end
      end
    end

    module PrimaryKey
      extend ActiveSupport::Concern

      def primary_key
        raise UndefinedPrimaryKeyAttributeError unless self.class.primary_key_attribute.present?
        send(self.class.primary_key_attribute)
      end

      PARAM_JOIN_STRING = '/'.freeze

      def to_param
        # for ActiveModel compliant
        if persisted?
          to_key.join PARAM_JOIN_STRING
        else
          nil
        end
      end

      def to_key
        # for ActiveModel compliant
        if persisted?
          [primary_key]
        else
          nil
        end
      end

      module ClassMethods
        attr_accessor :primary_key_attribute
      end

      class UndefinedPrimaryKeyAttributeError < StandardError
      end
    end

    module WithDAO
      extend ActiveSupport::Concern

      def model_dao_name
        dao.model_name
      end

      def dao
        @dao ||= load_dao
      end

      private

      # private setter => it can be given on object creation as a named argument, or in `_set_properties` method
      attr_writer :dao

      def load_dao
        key = self.class.dao_name
        raise UndefinedDAOError unless key.present?
        ArtirixDataModels::DAORegistry.send(key)
      end

      module ClassMethods
        attr_accessor :dao_name
      end

      class UndefinedDAOError < StandardError
      end
    end

    module CacheKey
      extend ActiveSupport::Concern

      def cache_key
        "#{model_dao_name}/#{primary_key}/#{_timestamp}"
      end
    end

    module PartialMode
      extend ActiveSupport::Concern

      def reload_with(new_data)
        _set_properties new_data
        self
      end

      def partial_mode?
        !full_mode?
      end

      def full_mode?
        !!@_full_mode
      end

      def mark_full_mode
        @_full_mode = true
      end

      def mark_partial_mode
        @_full_mode = false
      end

      def reload_model!
        dao.reload(self)
        self
      end

      private
      def nil_attribute(attribute)
        return nil if full_mode? || dao.partial_mode_fields.include?(attribute)
        reload_model!
        send(attribute)
      end

    end
  end
end
