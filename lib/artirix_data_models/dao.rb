module ArtirixDataModels
  module DAO
    extend ActiveSupport::Concern

    included do
      attr_reader :basic_model_dao
      delegate :partial_mode_fields, :reload, :get_full, :get, :get_some, :search, :model_name, :model_class, :gateway, to: :basic_model_dao
    end


    def initialize(gateway: nil, model_name: nil, model_class: nil, paths_factory: nil, fake_mode_factory: nil)
      model_class       = model_class || default_model_class
      gateway           = gateway || ArtirixDataModels::DAORegistry.gateway
      model_name        = model_name || default_model_name
      paths_factory     = paths_factory || default_path_factory
      fake_mode_factory = fake_mode_factory || default_fake_mode_factory
      @basic_model_dao  = ArtirixDataModels::DAORegistry.basic_class.new model_name, model_class, paths_factory, gateway, fake_mode_factory
    end

    def default_model_name
      self.class::MODEL_NAME
    end

    def default_model_class
      self.class::MODEL_CLASS
    end

    def default_path_factory
      self.class::Paths
    end

    def default_fake_mode_factory
      if defined?(self.class::FakeMode)
        self.class::FakeMode
      else
        FakeModes::Disabled
      end
    end

    module FakeModes
      module Factory

        def fake_mode_key
          raise NotImplementedError
        end

        def partial_mode_fields
          raise NotImplementedError
        end

        def get(model_pk)
          raise NotImplementedError
        end

        def get_full(model_pk, given_model_to_reload = nil)
          raise NotImplementedError
        end

        def get_some(model_pks)
          raise NotImplementedError
        end

        def search(from:, size:, ** params)
          raise NotImplementedError
        end

        def enabled?
          SimpleConfig.for(:site).try(:data_fake_mode).try(fake_mode_key)
        end
      end

      module Disabled
        def self.enabled?
          false
        end
      end
    end
  end
end
