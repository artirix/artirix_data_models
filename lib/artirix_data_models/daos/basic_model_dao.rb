class ArtirixDataModels::BasicModelDAO
  attr_reader :model_name, :model_class, :paths_factory, :fake_mode_factory, :gateway_factory, :loaded_gateway

  def initialize(model_name:, model_class:, paths_factory:, gateway:, fake_mode_factory:, gateway_factory:)
    @model_name        = model_name
    @model_class       = model_class
    @paths_factory     = paths_factory
    @loaded_gateway    = gateway
    @gateway_factory   = gateway_factory
    @fake_mode_factory = fake_mode_factory
  end

  def preloaded_gateway
    loaded_gateway.presence || gateway_factory.call
  end

  alias_method :gateway, :preloaded_gateway

  def partial_mode_fields
    if fake?
      fake_mode_factory.partial_mode_fields
    else
      ArtirixDataModels::DAORegistry.model_fields.partial_mode_fields_for model_name
    end
  end

  def get_full(model_pk, model_to_reload:, response_adaptor: nil, cache_adaptor: nil, **extra_options)
    path             = paths_factory.get_full model_pk
    response_adaptor ||= response_adaptor_for_reload(model_to_reload)

    _get path, response_adaptor: response_adaptor, fake_response: fake_get_full_response(model_pk, model_to_reload), cache_adaptor: cache_adaptor, **extra_options

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

    _get(path, response_adaptor: response_adaptor, fake_response: fake_get_response(model_pk), cache_adaptor: cache_adaptor, **extra_options)
  end

  def get_some(model_pks, cache_adaptor: nil, response_adaptor: nil, **extra_options)
    path             = paths_factory.get_some(model_pks)
    response_adaptor ||= response_adaptor_for_some

    _get(path, response_adaptor: response_adaptor, fake_response: fake_get_some_response(model_pks), cache_adaptor: cache_adaptor, **extra_options)
  rescue ArtirixDataModels::DataGateway::NotFound
    []
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
    fake_mode_factory.get model_pk
  end

  def fake_get_some_response(model_pks)
    return nil unless fake?
    fake_mode_factory.get_some model_pks
  end

  def fake_get_full_response(model_pk, model_to_reload = nil)
    return nil unless fake?
    fake_mode_factory.get_full model_pk, model_to_reload
  end

  def response_adaptor_for_reload(model_to_reload)
    model_adaptor_factory.with_block do |data_hash|
      model_to_reload.reload_with data_hash
    end
  end

  def response_adaptor_for_single
    model_adaptor_factory.single model_class
  end

  def response_adaptor_for_some(element_model_class = model_class)
    model_adaptor_factory.some element_model_class
  end

  def response_adaptor_for_collection(from, size, collection_element_model_class = model_class)
    model_adaptor_factory.collection collection_element_model_class, from, size
  end

  def empty_collection(from, size)
    empty_collection_for model_class, from, size
  end

  def empty_collection_for(model_class, from, size)
    ArtirixDataModels::EsCollection.empty model_class, from: from, size: size
  end

  def model_adaptor_factory
    ArtirixDataModels::GatewayResponseAdaptors::ModelAdaptor
  end

  def _get(path, response_adaptor: nil, body: nil, fake_response: nil, cache_adaptor: nil, gateway: nil)
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?
    g.get path, response_adaptor: response_adaptor, body: body, fake: fake?, fake_response: fake_response, cache_adaptor: cache_adaptor
  end

  def _post(path, response_adaptor: nil, body: nil, fake_response: nil, cache_adaptor: nil, gateway: nil)
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?
    g.post path, response_adaptor: response_adaptor, body: body, fake: fake?, fake_response: fake_response, cache_adaptor: cache_adaptor
  end

  def _put(path, response_adaptor: nil, body: nil, fake_response: nil, cache_adaptor: nil, gateway: nil)
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?
    g.put path, response_adaptor: response_adaptor, body: body, fake: fake?, fake_response: fake_response, cache_adaptor: cache_adaptor
  end

  def _delete(path, response_adaptor: nil, body: nil, fake_response: nil, cache_adaptor: nil, gateway: nil)
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?
    g.delete path, response_adaptor: response_adaptor, body: body, fake: fake?, fake_response: fake_response, cache_adaptor: cache_adaptor
  end

  def fake?
    return true if forced_fake_enabled?
    return false if forced_fake_disabled?
    fake_mode_factory.enabled?
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

end
