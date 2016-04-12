# :nocov:
def given_gateway_config(connection_url = nil)
  connection_url ||= 'http://example.com/other'
  
  before(:each) do
    config = ArtirixDataModels.configuration

    # fix in case of SimpleConfig (mocking SimpleConfig with rspec explodes if not)
    if defined?(SimpleConfig) && config.kind_of?(SimpleConfig::Config)
      SimpleConfig::Config.class_eval { public :singleton_class }
    end

    dg = config.try(:data_gateway) || double
    allow(dg).to receive(:url).and_return(connection_url)
    allow(config).to receive(:data_gateway).and_return(dg)
  end
end


def mock_gateway_response(response:,
                          method:,
                          path:,
                          body: nil,
                          json_body: true,
                          timeout: nil,
                          authorization_bearer: nil,
                          authorization_token_hash: nil,
                          gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  params_hash = {
    path:                     path,
    body:                     body,
    json_body:                json_body,
    timeout:                  timeout,
    authorization_bearer:     authorization_bearer,
    authorization_token_hash: authorization_token_hash
  }

  allow(gateway).to receive(:perform).with(method, params_hash).and_return response

  # check with body already parsed
  unless body.nil?
    body = body.kind_of?(String) ? body : body.to_json
    allow(gateway).to receive(:perform).with(method, params_hash.merge(body: body)).and_return response
  end
end

def mock_gateway_not_found_response(method:,
                                    path:,
                                    body: nil,
                                    json_body: true,
                                    timeout: nil,
                                    authorization_bearer: nil,
                                    authorization_token_hash: nil,
                                    gateway: nil)

  gateway ||= ArtirixDataModels::DAORegistry.gateway

  params_hash = {
    path:                     path,
    body:                     body,
    json_body:                json_body,
    timeout:                  timeout,
    authorization_bearer:     authorization_bearer,
    authorization_token_hash: authorization_token_hash
  }

  allow(gateway).to receive(:perform).with(method, params_hash).and_raise ArtirixDataModels::DataGateway::NotFound

  # check with body already parsed
  unless body.nil?
    body = body.kind_of?(String) ? body : body.to_json
    allow(gateway).to receive(:perform).with(method, params_hash.merge(body: body)).and_raise ArtirixDataModels::DataGateway::NotFound
  end
end

# GET
def mock_gateway_get_response(**params)
  mock_gateway_response method: :get, **params
end

def mock_gateway_get_not_found_response(**params)
  mock_gateway_not_found_response method: :get, **params
end

# POST
def mock_gateway_post_response(**params)
  mock_gateway_response method: :post, **params
end

def mock_gateway_post_not_found_response(**params)
  mock_gateway_not_found_response method: :post, **params
end

# PUT
def mock_gateway_put_response(**params)
  mock_gateway_response method: :put, **params
end

def mock_gateway_put_not_found_response(**params)
  mock_gateway_not_found_response method: :put, **params
end

# DELETE
def mock_gateway_delete_response(**params)
  mock_gateway_response method: :delete, **params
end

def mock_gateway_delete_not_found_response(**params)
  mock_gateway_not_found_response method: :delete, **params
end

# :nocov: