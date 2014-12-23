class ArtirixDataModels::BasicModelDAO
  attr_reader :model_name, :model_class, :paths_factory, :gateway, :fake_mode_factory

  def initialize(model_name, model_class, paths_factory, gateway, fake_mode_factory)
    @model_name        = model_name
    @model_class       = model_class
    @paths_factory     = paths_factory
    @gateway           = gateway
    @fake_mode_factory = fake_mode_factory
  end

  def partial_mode_fields
    if fake?
      fake_mode_factory.partial_mode_fields
    else
      ArtirixDataModels::DAORegistry.model_fields.partial_mode_fields_for model_name
    end
  end

  def reload(model)
    get_full model.primary_key, model_to_reload: model
  end

  def get_full(model_pk, model_to_reload: nil)
    model = model_to_reload || model_class.new

    path    = paths_factory.get_full model_pk
    adaptor = response_adaptor_for_reload(model)

    _get path, response_adaptor: adaptor, fake_response: fake_get_full_response(model_pk, model_to_reload)

    model.mark_full_mode
    model
  end

  def get(model_pk)
    path    = paths_factory.get model_pk
    adaptor = response_adaptor_for_single

    _get path, response_adaptor: adaptor, fake_response: fake_get_response(model_pk)
  end

  def get_some(model_pks)
    path    = paths_factory.get_some(model_pks)
    adaptor = response_adaptor_for_some

    _get path, response_adaptor: adaptor, fake_response: fake_get_some_response(model_pks)
  end

  def search(from: 0, size: nil, **other_params)
    size ||= SimpleConfig.for(:site).try(:search_page_size).try(:default) || ArtirixDataModels::EsCollection::DEFAULT_SIZE

    path    = paths_factory.search from: from, size: size, **other_params
    adaptor = response_adaptor_for_collection(from, size)

    _get path, response_adaptor: adaptor, fake_response: fake_search_response(from: from, size: size, **other_params)
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

  private

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

  def fake_search_response(options)
    return nil unless fake?
    fake_mode_factory.search options
  end

  def response_adaptor_for_reload(model_to_reload)
    model_adaptor_factory.with_block do |data_hash|
      model_to_reload.reload_with data_hash
    end
  end

  def response_adaptor_for_single
    model_adaptor_factory.single model_class
  end

  def response_adaptor_for_some
    model_adaptor_factory.some model_class
  end

  def response_adaptor_for_collection(from, size)
    model_adaptor_factory.collection model_class, from, size
  end

  def model_adaptor_factory
    ArtirixDataModels::GatewayResponseAdaptors::ModelAdaptor
  end

  def _get(path, response_adaptor: nil, body: nil, fake_response: nil)
    gateway.get path, response_adaptor: response_adaptor, body: body, fake: fake?, fake_response: fake_response
  end

  def fake?
    return true if forced_fake_enabled?
    return false if forced_fake_disabled?
    fake_mode_factory.enabled?
  end
end
