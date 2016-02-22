module ArtirixDataModels
  module ActiveNull

    def null
      null_class.get
    end

    def null_model(&block)
      @null_model_overrides = if block_given?
                                Module.new.tap { |m| m.module_eval(&block) }
                              end
    end

    def null_class
      @null_class ||= NullModelBuilder.new(self, @null_model_overrides).build
    end

    class NullModelBuilder
      attr_reader :model, :overrides

      def initialize(model, overrides)
        @model     = model
        @overrides = overrides
      end

      def build
        model = self.model
        null  = Naught.build do |config|
          config.impersonate model
          config.predicates_return false

          def nil?
            true
          end

          def present?
            false
          end

          def blank?
            true
          end

          def to_json
            '{}'
          end

          ##########################
          # ACTIVE MODEL COMPLIANT #
          ##########################

          def to_model
            self
          end

          def to_partial_path
            model._to_partial_path
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


          ##########
          # DRAPER #
          ##########

          if Object.const_defined? 'Draper'
            def decorate(options = {})
              decorator_class.decorate(self, options)
            end

            def decorator_class
              self.class.decorator_class
            end

            def decorator_class?
              self.class.decorator_class?
            end

            def applied_decorators
              []
            end

            def decorated_with?(decorator_class)
              false
            end

            def decorated?
              false
            end
          end
        end
        null.send(:include, Draper::Decoratable) if Object.const_defined? 'Draper'
        null.send(:include, overrides) if overrides
        null.send(:include, ArtirixDataModels::Model::ActiveModelCompliant)
        set_null_model null
      end

      def name
        base_name = model.name.split('::').last
        "Null#{base_name}"
      end

      def full_name
        return name if model.parent == Object
        "#{model.parent.name}::#{name}"
      end

      def set_null_model(null)
        model.parent.const_set name, null
      end
    end

  end
end