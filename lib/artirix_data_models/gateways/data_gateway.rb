class ArtirixDataModels::DataGateway
  attr_reader :connection, :post_as_json

  def initialize(connection: nil, post_as_json: true)
    @connection   = connection || DefaultConnectionLoader.default_connection
    @post_as_json = !!post_as_json
  end

  def get(path, response_adaptor: nil, body: nil, fake: false, fake_response: nil, cache_adaptor: nil, **ignored_options)
    if fake
      response_body = fake_response
    elsif cache_adaptor.present?
      response_body = cache_adaptor.call { perform_get(path, body) }
    else
      response_body = perform_get(path, body)
    end
    parse_get_response(response_body, response_adaptor)
  end

  def post(path, response_adaptor: nil, body: nil, fake: false, fake_response: nil, **ignored_options)
    if fake
      response_body = fake_response
    else
      response_body = perform_post(path, body)
    end
    parse_post_response(response_body, response_adaptor)
  end

  private

  def perform_get(path, body = nil)
    response = connect_get(path, body)
    if response.success?
      response.body
    elsif response.status.to_i == 404
      raise NotFound, path
    else
      raise GatewayError, "method: get, path: #{path}, status: #{response.status}, body: #{response.body}"
    end
  end

  def perform_post(path, body = nil)
    response = connect_post(path, body)
    if response.success?
      response.body
    elsif response.status.to_i == 404
      raise NotFound, path
    else
      raise GatewayError, "method: post, path: #{path}, status: #{response.status}, body: #{response.body}"
    end
  end

  def connect_get(path, body)
    connection.get path do |req|
      req.body = body_to_json body unless body.nil?
    end
  rescue Faraday::ConnectionFailed => e
    raise ConnectionError, "method: get, path: #{path}, error: #{e}"
  end

  def connect_post(path, body)
    connection.post path do |req|
      unless body.nil?
        req.body = body_to_json body
        req.headers['Content-Type'] = 'application/json'
      end
    end
  rescue Faraday::ConnectionFailed => e
    raise ConnectionError, "method: post, path: #{path}, error: #{e}"
  end

  def body_to_json(body)
    case body
      when String
        body
      else
        body.to_json
    end
  end

  def parse_post_response(result, response_adaptor)
    parse_common_response(result, response_adaptor)
  end

  def parse_get_response(result, response_adaptor)
    parse_common_response(result, response_adaptor)
  end

  def parse_common_response(result, response_adaptor)
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

    class << self
      attr_accessor :config

      def default_connection
        url = connection_url

        Faraday.new(url: url, request: { params_encoder: Faraday::FlatParamsEncoder }) do |faraday|
          faraday.request :url_encoded # form-encode POST params
          faraday.response :logger # log requests to STDOUT
          faraday.basic_auth(config.login, config.password) if basic_auth?
          faraday.adapter Faraday.default_adapter
        end
      end

      # Configuration access

      def config
        @config ||= SimpleConfig.for(:site).data_gateway
      end

      def connection_url
        config.url
      end

      def basic_auth?
        config.respond_to?(:login) && config.respond_to?(:password)
      end
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
