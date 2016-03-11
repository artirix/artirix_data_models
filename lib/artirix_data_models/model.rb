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

    module WithoutDefaultAttributes
      extend ActiveSupport::Concern

      included do
        include ActiveModelCompliant
        include Attributes
        include PrimaryKey
        include WithDAO
        include CacheKey
        include PartialMode
      end
    end

    module CompleteModel
      extend ActiveSupport::Concern

      included do
        include ActiveModelCompliant
        include Attributes
        include PrimaryKey
        include WithDAO
        include CacheKey
        include PartialMode

        # after Attributes and PartialMode
        include Attributes::WithDefaultAttributes
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

    module PublicWriters
      extend ActiveSupport::Concern

      included do
        include Attributes::PublicWriters
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

      module ClassMethods
        def active_model_compliant?
          true
        end
      end
    end

    module Attributes
      extend ActiveSupport::Concern

      included do
        include KeywordInit
        include Inspectable
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

      module ClassMethods
        def attribute(*attributes)
          options = attributes.extract_options!
          attributes.each { |attribute| _define_attribute attribute, options }
        end

        def attribute_config
          @attribute_config ||= AttributeConfig.new
        end

        def defined_attributes
          attribute_config.attributes
        end

        # deal with model inheritance
        def all_defined_attributes
          attribute_config.all_attributes
        end

        def inherited(child_class)
          child_class.attribute_config.parent_attribute_config = attribute_config
        end

        def writer_visibility
          @writer_visibility ||= :private
        end

        def writer_visibility=(visibility)
          raise InvalidArgumentError, "Invalid visibility #{visibility.inspect}" unless [:public, :private, :protected].include? visibility
          @writer_visibility = visibility
        end

        private
        def _define_attribute(attribute, options)
          at = attribute.to_sym
          _define_getter(at, options)
          _define_presence(at, options)
          _define_writer(at, options)

          attribute_config.add_attribute at
        end

        def _define_writer(attribute, options)
          skip_option = Array(options.fetch(:skip, []))
          return nil if skip_option.include?(:writer) || skip_option.include?(:setter)

          vis = options.fetch(:writer_visibility, writer_visibility)

          attr_writer attribute
          writer = "#{attribute}="

          if vis == :private
            private writer
          elsif vis == :protected
            protected writer
          end

          writer
        end

        def _define_presence(attribute, options)
          skip_option = Array(options.fetch(:skip, []))
          return nil if skip_option.include?(:presence) || skip_option.include?(:predicate)

          presence_method = "#{attribute}?"
          define_method presence_method do
            send(attribute).present?
          end
        end

        def _define_getter(attribute, options)
          skip_option = Array(options.fetch(:skip, []))
          return nil if skip_option.include?(:reader) || skip_option.include?(:getter)

          variable_name = "@#{attribute}"
          dir_get_name  = Attributes.direct_getter_method_name(attribute)
          reader        = attribute.to_s

          define_method dir_get_name do
            instance_variable_get variable_name
          end

          define_method(reader) do
            val = send dir_get_name
            if val.nil?
              nil_attribute(attribute)
            else
              val
            end
          end

          vis = options.fetch(:reader_visibility, :public)

          if vis == :private
            private reader
          elsif vis == :protected
            protected reader
          end

        end
      end

      module PublicWriters
        extend ActiveSupport::Concern
        included do
          self.writer_visibility = :public
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
          always_in_partial_mode(:_timestamp) if respond_to?(:always_in_partial_mode)

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

      def set_primary_key(value)
        raise UndefinedPrimaryKeyAttributeError unless self.class.primary_key_attribute.present?
        send("#{self.class.primary_key_attribute}=", value)
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

      EMPTY_TIMESTAMP = 'no_time'.freeze
      SEPARATOR       = '/'.freeze

      def cache_key
        m = try(:model_dao_name) || self.class
        i = try(:primary_key) || try(:id) || try(:object_id)
        t = try(:_timestamp) || try(:updated_at) || EMPTY_TIMESTAMP
        [
          m.to_s.parameterize,
          i.to_s.parameterize,
          t.to_s.parameterize,
        ].join SEPARATOR
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
        if @_full_mode.nil?
          self.class.default_full_mode?
        else
          @_full_mode
        end
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

      def force_partial_mode_fields(fields)
        @_forced_partial_mode_fields = fields.map &:to_s
      end

      def unforce_partial_mode_fields
        @_forced_partial_mode_fields = nil
      end

      def forced_partial_mode_fields?
        !!@_forced_partial_mode_fields && @_forced_partial_mode_fields.present?
      end

      private
      def in_partial_mode_field?(attribute)
        return true if self.class.is_always_in_partial_mode?(attribute)

        list = forced_partial_mode_fields? ? @_forced_partial_mode_fields : dao.partial_mode_fields
        list.include?(attribute.to_s) || list.include?(attribute.to_sym)
      end

      def nil_attribute(attribute)
        return nil if full_mode? || in_partial_mode_field?(attribute)
        reload_model!
        send(attribute)
      end

      module ClassMethods
        def new_full_mode(*args, &block)
          new(*args, &block).tap { |x| x.mark_full_mode }
        end

        def always_in_partial_mode(attribute)
          attribute_config.always_in_partial_mode(attribute)
        end

        def remove_always_in_partial_mode(attribute)
          attribute_config.remove_always_in_partial_mode(attribute)
        end

        def is_always_in_partial_mode?(attribute)
          attribute_config.is_always_in_partial_mode?(attribute)
        end

        def default_full_mode?
          !!attribute_config.default_full_mode
        end

        def mark_full_mode_by_default
          attribute_config.default_full_mode = true
        end

        def mark_partial_mode_by_default
          attribute_config.default_full_mode = false
        end
      end
    end

    class AttributeConfig
      attr_reader :attribute_list, :always_in_partial_mode_list
      attr_accessor :parent_attribute_config, :default_full_mode

      def initialize
        @attribute_list              = Set.new
        @always_in_partial_mode_list = Set.new
        @parent_attribute_config     = nil
        @default_full_mode           = false
      end

      def attributes
        attribute_list.to_a
      end

      def all_attributes
        Array(parent_attribute_config.try(:attributes)) + attributes
      end

      def add_attribute(attribute)
        attribute_list << attribute
      end

      def always_in_partial_mode(attribute)
        @always_in_partial_mode_list << (attribute.to_s)
      end

      def remove_always_in_partial_mode(attribute)
        @always_in_partial_mode_list.delete attribute.to_s
      end

      def is_always_in_partial_mode?(attribute)
        @always_in_partial_mode_list.include?(attribute.to_s) || parent_attribute_config.try(:is_always_in_partial_mode?, attribute)
      end

    end
  end
end
