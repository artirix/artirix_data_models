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

def mock_gateway_get_response(response:, path:, body: nil, gateway: nil)
  gateway ||= ArtirixDataModels::DAORegistry.gateway

  allow(gateway).to receive(:perform_get).with(path, body).and_return response
end
