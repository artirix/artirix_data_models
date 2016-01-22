# :nocov:
def given_gateway_config(connection_url = nil)
  connection_url ||= 'http://example.com/other'
  before(:all) do
    c = connection_url
    SimpleConfig.for(:site) do
      group :data_gateway do
        set :url, c
      end
    end
  end
end

# GET

def mock_gateway_get_response(response:, path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform).with(:get, path, body).and_return response
end

def mock_gateway_get_not_found_response(path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform).with(:get, path, body).and_raise ArtirixDataModels::DataGateway::NotFound
end

# POST

def mock_gateway_post_response(response:, path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform).with(:post, path, body).and_return response
end

def mock_gateway_post_not_found_response(path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform).with(:post, path, body).and_raise ArtirixDataModels::DataGateway::NotFound
end

# PUT

def mock_gateway_put_response(response:, path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform).with(:put, path, body).and_return response
end

def mock_gateway_put_not_found_response(path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform).with(:put, path, body).and_raise ArtirixDataModels::DataGateway::NotFound
end

# DELETE

def mock_gateway_delete_response(response:, path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform).with(:delete, path, body).and_return response
end

def mock_gateway_delete_not_found_response(path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform).with(:delete, path, body).and_raise ArtirixDataModels::DataGateway::NotFound
end

# :nocov: