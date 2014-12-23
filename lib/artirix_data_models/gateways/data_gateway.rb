class ArtirixDataModels::DataGateway
  attr_reader :connection

  def initialize(connection: nil)
    @connection = connection || DefaultConnectionLoader.default_connection
  end

  def get(path, response_adaptor: nil, body: nil, fake: false, fake_response: nil)
    if fake
      response_body = fake_response
    else
      response_body = perform_get(path, body)
    end
    parse_get_response(response_body, response_adaptor)
  end

  private

  def perform_get(path, body = nil)
    response = connect_get(path, body)
    if response.success?
      response.body
    elsif response.status.to_i == 404
      raise NotFound, path
    else
      raise GatewayError, "path: #{path}, status: #{response.status}, body: #{response.body}"
    end
  end

  def connect_get(path, body)
    connection.get path do |req|
      req.body = body_to_json body unless body.nil?
    end
  rescue Faraday::ConnectionFailed => e
    raise ConnectionError, "path: #{path}, error: #{e}"
  end

  def body_to_json(body)
    case body
      when String
        body
      else
        body.to_json
    end
  end

  def parse_get_response(result, response_adaptor)
    if result.present?
      parsed_response = Oj.load result, symbol_keys: true
    else
      parsed_response = nil
    end

    if response_adaptor.present?
      response_adaptor.call parsed_response
    else
      parsed_response
    end

  rescue Oj::ParseError => e
    raise ParseError, "response: #{result}, #{e}"
  end

  module DefaultConnectionLoader
    def self.default_connection
      url = config_connection_url
      Faraday.new(url: url) do |faraday|
        faraday.request :url_encoded # form-encode POST params
        faraday.response :logger # log requests to STDOUT
        faraday.adapter Faraday.default_adapter
      end
    end

    def self.config_connection_url
      SimpleConfig.for(:site).data_gateway.url
    end
  end

  class Error < StandardError
  end

  class NotFound < Error
  end

  class ParseError < Error
  end

  class GatewayError < Error
  end

  class ConnectionError < GatewayError
  end
end
