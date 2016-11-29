module ArtirixDataModels
  module DAO
    extend ActiveSupport::Concern

    DELEGATED_METHODS = [
      :partial_mode_fields,

      :model_name,
      :model_class,

      :paths_factory,
      :fake_mode_factory,

      :gateway,

      :force_fake_enabled,
      :force_fake_disabled,
      :remove_force_fake,
      :fake?,
      :forced_fake_enabled?,
      :forced_fake_disabled?,

      :empty_collection,
      :empty_collection_for,

      :perform_get,
      :perform_post,
      :perform_put,
      :perform_delete,

      :dao_registry,
      :dao_registry=,
      :set_dao_registry,
      :dao_registry_loader,
      :dao_registry_loader=,
      :set_dao_registry_loader,
      :set_default_dao_registry_loader,
      :set_default_dao_registry,
    ]

    included do
      include ArtirixDataModels::DAOConcerns::WithResponseAdaptors
      include ArtirixDataModels::WithDAORegistry

      attr_reader :basic_model_dao
      delegate *DELEGATED_METHODS, to: :basic_model_dao
    end


    def initialize(dao_registry: nil,
                   dao_registry_loader: nil,
                   gateway: nil,
                   gateway_factory: nil,
                   ignore_default_gateway: false,
                   model_name: nil,
                   model_class: nil,
                   paths_factory: nil,
                   fake_mode_factory: nil)

      model_name ||= default_model_name
      model_class ||= default_model_class
      paths_factory ||= default_path_factory
      fake_mode_factory ||= default_fake_mode_factory

      # temporary dao registry to load basic_class only
      create_basic_model_dao dao_registry: dao_registry,
                             dao_registry_loader: dao_registry_loader,
                             fake_mode_factory: fake_mode_factory,
                             gateway: gateway,
                             gateway_factory: gateway_factory,
                             ignore_default_gateway: ignore_default_gateway,
                             model_class: model_class,
                             model_name: model_name,
                             paths_factory: paths_factory

    end

    def create_basic_model_dao(dao_registry:,
                               dao_registry_loader:,
                               fake_mode_factory:,
                               gateway:,
                               gateway_factory:,
                               ignore_default_gateway:,
                               model_class:,
                               model_name:,
                               paths_factory:,
                               **other_basic_model_dao_params)

      dr = ArtirixDataModels::WithDAORegistry.loader_or_registry_or_default dao_registry_loader: dao_registry_loader,
                                                                            dao_registry: dao_registry

      basic_model_class = dr.get(:basic_class)

      @basic_model_dao = basic_model_class.new model_name: model_name,
                                               model_class: model_class,
                                               fake_mode_factory: fake_mode_factory,
                                               paths_factory: paths_factory,
                                               gateway: gateway,
                                               gateway_factory: gateway_factory,
                                               dao_registry: dao_registry,
                                               dao_registry_loader: dao_registry_loader,
                                               ignore_default_gateway: ignore_default_gateway,
                                               **other_basic_model_dao_params
    end

    def default_model_name
      defined?(self.class::MODEL_NAME) ? self.class::MODEL_NAME : nil
    end

    def default_model_class
      defined?(self.class::MODEL_CLASS) ? self.class::MODEL_CLASS : nil
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

    def in_fake_mode
      return unless block_given?

      begin
        basic_model_dao.force_fake_enabled
        yield
      ensure
        basic_model_dao.remove_force_fake
      end
    end

    ###############################
    # DELEGATE TO BASIC_MODEL_DAO #
    ###############################

    def reload(model)
      get_full model.primary_key, model_to_reload: model
    end

    def get_full(model_pk, model_to_reload: nil, cache_adaptor: nil, **extra_options)
      # we do not check in the registry, since it could be a reload
      model_to_reload ||= new_model_with_pk(model_pk)
      cache_adaptor ||= cache_model_adaptor_for_get_full(model_pk, model_to_reload: model_to_reload, **extra_options)

      model = basic_model_dao.get_full(model_pk, model_to_reload: model_to_reload, cache_adaptor: cache_adaptor, **extra_options)

      complete_model model
    end

    def get(model_pk, cache_adaptor: nil, **extra_options)
      model = dao_registry.get_model model_name, model_pk
      return model if model.present?

      cache_adaptor ||= cache_model_adaptor_for_get(model_pk, **extra_options)

      model = basic_model_dao.get(model_pk, cache_adaptor: cache_adaptor, **extra_options)

      complete_model model
    end

    def find(model_pk, cache_adaptor: nil, **extra_options)
      model = dao_registry.get_model model_name, model_pk
      return model if model.present?

      cache_adaptor ||= cache_model_adaptor_for_find(model_pk, **extra_options)

      model = basic_model_dao.find(model_pk, cache_adaptor: cache_adaptor, **extra_options)

      complete_model model
    end

    def get_some(model_pks, cache_adaptor: nil, **extra_options)
      registered = Array(model_pks).map do |model_pk|
        [
          model_pk,
          dao_registry.get_model(model_name, model_pk)
        ]
      end.to_h

      return registered.values if registered.values.all?(&:present?)

      # load only the missing
      missing_pks = registered.select { |_k, v| v.blank? }.keys

      cache_adaptor ||= cache_model_adaptor_for_get_some(missing_pks, **extra_options)

      models = basic_model_dao.get_some(missing_pks, cache_adaptor: cache_adaptor, **extra_options)

      Array(models).each do |model|
        complete_model model
      end

      list = registered.values.compact.concat(models)

      # reorder with the same order of the model_pks
      # (if for any reason it does not have a primary key or if it is not in the list, then use -1 so they are at the start)
      list.sort_by { |m| pk = m.try :primary_key; model_pks.index(pk) || -1 }
    end

    private

    def new_model_with_pk(model_pk)
      model_class.new.tap do |m|
        if model_class.try(:primary_key_attribute).present? && m.respond_to?(:set_primary_key)
          m.set_primary_key model_pk
        end
      end
    end

    def cache_model_adaptor_for_find(model_pk, **extra_options)
      cache_model_adaptor_for_get model_pk, **extra_options
    end

    def cache_model_adaptor_for_get(model_pk, **extra_options)
      ArtirixDataModels::CachedActionAdaptor::Get.new(dao_name: model_name, model_pk: model_pk, **extra_options)
    end

    def cache_model_adaptor_for_get_full(model_pk, model_to_reload: nil, **extra_options)
      ArtirixDataModels::CachedActionAdaptor::GetFull.new(dao_name: model_name, model: model_to_reload, model_pk: model_pk, **extra_options)
    end

    def cache_model_adaptor_for_get_some(model_pks, **extra_options)
      ArtirixDataModels::CachedActionAdaptor::GetSome.new(dao_name: model_name, model_pks: model_pks, **extra_options)
    end

    def complete_model(model)
      if model
        dao_registry.register_model model
        model.try :set_dao_registry_loader, dao_registry_loader
      end

      model
    end

    module FakeModes
      module Factory

        def fake_mode_key
          raise NotImplementedError
        end

        def partial_mode_fields
          raise NotImplementedError
        end

        def get(_model_pk)
          raise NotImplementedError
        end

        def get_full(_model_pk, given_model_to_reload = nil)
          raise NotImplementedError
        end

        def get_some(_model_pks)
          raise NotImplementedError
        end

        def enabled?
          ArtirixDataModels.configuration.try(:data_fake_mode).try(fake_mode_key)
        end

        def partial_hash_from_model(given_model_to_reload)
          return {} if given_model_to_reload.nil?

          list = partial_mode_fields.map do |at|
            if given_model_to_reload.respond_to? at
              [at, given_model_to_reload.send(at)]
            else
              nil
            end
          end

          Hash[list.compact]
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
