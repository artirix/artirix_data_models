class ArtirixDataModels::BasicModelDAO
  include ArtirixDataModels::DAOConcerns::WithResponseAdaptors
  include ArtirixDataModels::WithDAORegistry

  attr_reader :model_name, :model_class, :paths_factory, :fake_mode_factory, :gateway_factory

  def initialize(dao_registry: nil,
                 dao_registry_loader: nil,
                 model_name:,
                 model_class:,
                 paths_factory:,
                 gateway:,
                 fake_mode_factory:,
                 gateway_factory:,
                 ignore_default_gateway: false)

    set_dao_registry_and_loader dao_registry_loader, dao_registry

    @model_name             = model_name
    @model_class            = model_class
    @paths_factory          = paths_factory
    @loaded_gateway         = gateway
    @gateway_factory        = gateway_factory
    @fake_mode_factory      = fake_mode_factory
    @ignore_default_gateway = ignore_default_gateway
  end

  def default_gateway_available?
    !@ignore_default_gateway
  end

  def loaded_gateway
    @loaded_gateway ||= if gateway_factory.blank? && default_gateway_available?
                          dao_registry.get(:gateway)
                        end
  end

  ###########
  # ACTIONS #
  ###########

  def get_full(model_pk, model_to_reload:, response_adaptor: nil, cache_adaptor: nil, **extra_options)
    path             = paths_factory.get_full model_pk
    response_adaptor ||= response_adaptor_for_reload(model_to_reload)

    perform_get path, response_adaptor: response_adaptor, fake_response: fake_get_full_response(model_pk, model_to_reload), cache_adaptor: cache_adaptor, **extra_options

    model_to_reload.mark_full_mode
    model_to_reload
  end

  def get(model_pk, cache_adaptor: nil, **extra_options)
    find(model_pk, cache_adaptor: cache_adaptor, **extra_options)
  rescue ArtirixDataModels::DataGateway::NotFound
    nil
  end

  def find(model_pk, cache_adaptor: nil, response_adaptor: nil, **extra_options)
    path             = paths_factory.get model_pk
    response_adaptor ||= response_adaptor_for_single

    perform_get(path, response_adaptor: response_adaptor, fake_response: fake_get_response(model_pk), cache_adaptor: cache_adaptor, **extra_options)
  end

  def get_some(model_pks, cache_adaptor: nil, response_adaptor: nil, **extra_options)
    path             = paths_factory.get_some(model_pks)
    response_adaptor ||= response_adaptor_for_some

    perform_get(path, response_adaptor: response_adaptor, fake_response: fake_get_some_response(model_pks), cache_adaptor: cache_adaptor, **extra_options)
  rescue ArtirixDataModels::DataGateway::NotFound
    []
  end

  ###########
  # GATEWAY #
  ###########

  def preloaded_gateway
    loaded_gateway.presence || gateway_factory.call
  end

  alias_method :gateway, :preloaded_gateway

  def partial_mode_fields
    if fake?
      fake_mode_factory.partial_mode_fields
    else
      dao_registry.get(:model_fields).partial_mode_fields_for model_name
    end
  end

  def raise_no_gateway
    msg = 'no gateway passed to request, no gateway configured on creation'
    if gateway_factory.present?
      msg = "#{msg}, and no gateway returned by the factory"
    else
      msg = "#{msg}, and no gateway factory configured on creation"
    end

    raise NoGatewayConfiguredError, msg
  end

  class NoGatewayConfiguredError < StandardError
  end

  #############
  # FAKE MODE #
  #############

  def fake?
    return true if forced_fake_enabled?
    return false if forced_fake_disabled?
    fake_mode_factory.enabled?
  end

  def force_fake_enabled
    @_forced_fake_enabled = true
  end

  def force_fake_disabled
    @_forced_fake_enabled = false
  end

  def remove_force_fake
    @_forced_fake_enabled = nil
  end

  def forced_fake_enabled?
    return false if @_forced_fake_enabled.nil?
    !!@_forced_fake_enabled
  end

  def forced_fake_disabled?
    return false if @_forced_fake_enabled.nil?
    !@_forced_fake_enabled
  end

  def fake_get_response(model_pk)
    return nil unless fake?
    -> { fake_mode_factory.get model_pk }
  end

  def fake_get_some_response(model_pks)
    return nil unless fake?
    -> { fake_mode_factory.get_some model_pks }
  end

  def fake_get_full_response(model_pk, model_to_reload = nil)
    return nil unless fake?
    -> { fake_mode_factory.get_full model_pk, model_to_reload }
  end

  def empty_collection(from, size)
    empty_collection_for model_class, from, size
  end

  def empty_collection_for(model_class, from, size)
    ArtirixDataModels::EsCollection.empty model_class, from: from, size: size
  end

  #################
  # PERFORM CALLS #
  #################

  def perform_get(path, response_adaptor: nil, body: nil, fake_response: nil, cache_adaptor: nil, timeout: nil, gateway: nil)
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.get path,
          response_adaptor: response_adaptor,
          body:             body,
          timeout:          timeout,
          fake:             fake?,
          fake_response:    fake_response,
          cache_adaptor:    cache_adaptor
  end


  def perform_post(path, response_adaptor: nil, body: nil, fake_response: nil, cache_adaptor: nil, timeout: nil, gateway: nil)
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.post path,
           response_adaptor: response_adaptor,
           body:             body,
           timeout:          timeout,
           fake:             fake?,
           fake_response:    fake_response,
           cache_adaptor:    cache_adaptor
  end

  def perform_put(path, response_adaptor: nil, body: nil, fake_response: nil, cache_adaptor: nil, timeout: nil, gateway: nil)
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.put path,
          response_adaptor: response_adaptor,
          body:             body,
          timeout:          timeout,
          fake:             fake?,
          fake_response:    fake_response,
          cache_adaptor:    cache_adaptor
  end

  def perform_delete(path, response_adaptor: nil, body: nil, fake_response: nil, cache_adaptor: nil, timeout: nil, gateway: nil)
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.delete path,
             response_adaptor: response_adaptor,
             body:             body,
             timeout:          timeout,
             fake:             fake?,
             fake_response:    fake_response,
             cache_adaptor:    cache_adaptor
  end

  # old names
  alias_method :_get, :perform_get
  alias_method :_post, :perform_post
  alias_method :_put, :perform_put
  alias_method :_delete, :perform_delete

end
