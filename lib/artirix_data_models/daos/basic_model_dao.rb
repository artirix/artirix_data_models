class ArtirixDataModels::BasicModelDAO
  include ArtirixDataModels::DAOConcerns::WithResponseAdaptors
  include ArtirixDataModels::WithADMRegistry

  attr_reader :model_name, :model_class, :paths_factory, :fake_mode_factory, :gateway_factory

  def initialize(adm_registry: nil,
                 adm_registry_loader: nil,
                 model_name:,
                 model_class:,
                 paths_factory:,
                 gateway:,
                 fake_mode_factory:,
                 gateway_factory:,
                 ignore_default_gateway: false)

    set_adm_registry_and_loader adm_registry_loader, adm_registry

    @model_name = model_name
    @model_class = model_class
    @paths_factory = paths_factory
    @loaded_gateway = gateway
    @gateway_factory = gateway_factory
    @fake_mode_factory = fake_mode_factory
    @ignore_default_gateway = ignore_default_gateway
  end

  def default_gateway_available?
    !@ignore_default_gateway
  end

  def loaded_gateway
    @loaded_gateway ||= if gateway_factory.blank? && default_gateway_available?
                          adm_registry.get(:gateway)
                        end
  end

  ###########
  # ACTIONS #
  ###########

  def get_full(model_pk, model_to_reload:, path: nil, fake_response: nil, cache_adaptor: nil, response_adaptor: nil, **extra_options)
    path ||= paths_factory.get_full model_pk
    response_adaptor ||= response_adaptor_for_reload(model_to_reload)
    fake_response ||= fake_get_full_response(model_pk, model_to_reload)

    perform_get path, response_adaptor: response_adaptor, fake_response: fake_response, cache_adaptor: cache_adaptor, **extra_options

    model_to_reload.mark_full_mode
    model_to_reload
  end

  def get(*args)
    find *args
  rescue ArtirixDataModels::DataGateway::NotFound
    nil
  end

  def find(model_pk, path: nil, fake_response: nil, cache_adaptor: nil, response_adaptor: nil, **extra_options)
    path ||= paths_factory.get model_pk
    response_adaptor ||= response_adaptor_for_single
    fake_response ||= fake_get_response(model_pk)

    perform_get path,
                response_adaptor: response_adaptor,
                fake_response: fake_response,
                cache_adaptor: cache_adaptor,
                **extra_options
  end

  def get_some(model_pks, path: nil, fake_response: nil, cache_adaptor: nil, response_adaptor: nil, **extra_options)
    path ||= paths_factory.get_some(model_pks)
    response_adaptor ||= response_adaptor_for_some
    fake_response ||= fake_get_some_response(model_pks)
    perform_get path,
                response_adaptor: response_adaptor,
                fake_response: fake_response,
                cache_adaptor: cache_adaptor,
                **extra_options
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
      adm_registry.get(:model_fields).partial_mode_fields_for model_name
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

  def perform_get(path,
                  authorization_bearer: nil,
                  authorization_token_hash: nil,
                  body: nil,
                  cache_adaptor: nil,
                  fake: nil,
                  fake_response: nil,
                  gateway: nil,
                  headers: nil,
                  json_body: true,
                  json_parse_response: true,
                  response_adaptor: nil,
                  timeout: nil
  )

    fake = fake.nil? ? fake? : fake
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.get path,
          authorization_bearer: authorization_bearer,
          authorization_token_hash: authorization_token_hash,
          body: body,
          cache_adaptor: cache_adaptor,
          fake: fake,
          fake_response: fake_response,
          headers: headers,
          json_body: json_body,
          json_parse_response: json_parse_response,
          response_adaptor: response_adaptor,
          timeout: timeout
  end


  def perform_post(path,
                   authorization_bearer: nil,
                   authorization_token_hash: nil,
                   body: nil,
                   cache_adaptor: nil,
                   fake: nil,
                   fake_response: nil,
                   gateway: nil,
                   headers: nil,
                   json_body: true,
                   json_parse_response: true,
                   response_adaptor: nil,
                   timeout: nil
  )

    fake = fake.nil? ? fake? : fake
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.post path,
           authorization_bearer: authorization_bearer,
           authorization_token_hash: authorization_token_hash,
           body: body,
           cache_adaptor: cache_adaptor,
           fake: fake,
           fake_response: fake_response,
           headers: headers,
           json_body: json_body,
           json_parse_response: json_parse_response,
           response_adaptor: response_adaptor,
           timeout: timeout
  end

  def perform_put(path,
                  authorization_bearer: nil,
                  authorization_token_hash: nil,
                  body: nil,
                  cache_adaptor: nil,
                  fake: nil,
                  fake_response: nil,
                  gateway: nil,
                  headers: nil,
                  json_body: true,
                  json_parse_response: true,
                  response_adaptor: nil,
                  timeout: nil)

    fake = fake.nil? ? fake? : fake
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.put path,
          authorization_bearer: authorization_bearer,
          authorization_token_hash: authorization_token_hash,
          body: body,
          cache_adaptor: cache_adaptor,
          fake: fake,
          fake_response: fake_response,
          headers: headers,
          json_body: json_body,
          json_parse_response: json_parse_response,
          response_adaptor: response_adaptor,
          timeout: timeout

  end

  def perform_patch(path,
                    authorization_bearer: nil,
                    authorization_token_hash: nil,
                    body: nil,
                    cache_adaptor: nil,
                    fake: nil,
                    fake_response: nil,
                    gateway: nil,
                    headers: nil,
                    json_body: true,
                    json_parse_response: true,
                    response_adaptor: nil,
                    timeout: nil)

    fake = fake.nil? ? fake? : fake
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.patch path,
            authorization_bearer: authorization_bearer,
            authorization_token_hash: authorization_token_hash,
            body: body,
            cache_adaptor: cache_adaptor,
            fake: fake,
            fake_response: fake_response,
            headers: headers,
            json_body: json_body,
            json_parse_response: json_parse_response,
            response_adaptor: response_adaptor,
            timeout: timeout
  end

  def perform_delete(path,
                     authorization_bearer: nil,
                     authorization_token_hash: nil,
                     body: nil,
                     cache_adaptor: nil,
                     fake: nil,
                     fake_response: nil,
                     gateway: nil,
                     headers: nil,
                     json_body: true,
                     json_parse_response: true,
                     response_adaptor: nil,
                     timeout: nil)

    fake = fake.nil? ? fake? : fake
    g = gateway.presence || preloaded_gateway
    raise_no_gateway unless g.present?

    g.delete path,
             authorization_bearer: authorization_bearer,
             authorization_token_hash: authorization_token_hash,
             body: body,
             cache_adaptor: cache_adaptor,
             fake: fake,
             fake_response: fake_response,
             headers: headers,
             json_body: json_body,
             json_parse_response: json_parse_response,
             response_adaptor: response_adaptor,
             timeout: timeout
  end

  # old names
  alias_method :_get, :perform_get
  alias_method :_post, :perform_post
  alias_method :_put, :perform_put
  alias_method :_patch, :perform_patch
  alias_method :_delete, :perform_delete

end
