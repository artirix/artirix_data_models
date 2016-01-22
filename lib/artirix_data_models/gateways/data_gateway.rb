class ArtirixDataModels::DataGateway
  attr_reader :connection, :post_as_json

  def initialize(connection: nil, post_as_json: true)
    @connection   = connection || DefaultConnectionLoader.default_connection
    @post_as_json = !!post_as_json
  end

  def get(path, **opts)
    call :get, path, **opts
  end

  def post(path, **opts)
    call :post, path, **opts
  end

  def put(path, **opts)
    call :put, path, **opts
  end

  def delete(path, **opts)
    call :delete, path, **opts
  end

  def call(method, path, json_body: true, response_adaptor: nil, body: nil, fake: false, fake_response: nil, cache_adaptor: nil, **_ignored_options)
    if fake
      response_body = fake_response
    elsif cache_adaptor.present?
      response_body = cache_adaptor.call { perform(method, path, body, json_body) }
    else
      response_body = perform(method, path, body, json_body)
    end
    parse_response(response_body, response_adaptor)
  end

  private

  def perform_get(path, body = nil, json_body = true)
    perform :get, path, body, json_body
  end

  def perform_post(path, body = nil, json_body = true)
    perform :post, path, body, json_body
  end

  def perform_put(path, body = nil, json_body = true)
    perform :put, path, body, json_body
  end

  def perform_delete(path, body = nil, json_body = true)
    perform :delete, path, body, json_body
  end

  def perform(method, path, body = nil, json_body = true)
    response = connect(method, path, body, json_body)
    treat_response(response, method, path)
  end

  def connect(method, path, body = nil, json_body = true)
    # binding.pry if method == :delete
    connection.send(method, path) do |req|
      # binding.pry if method == :delete
      unless body.nil?
        if json_body
          req.body                    = body_to_json body
          req.headers['Content-Type'] = 'application/json'
        else
          req.body = body
        end
      end
    end
  rescue Faraday::ConnectionFailed => e
    raise ConnectionError, "method: #{method}, path: #{path}, error: #{e}"
  end

  def treat_response(response, method, path)
    if response.success?
      response.body
    elsif response.status.to_i == 404
      raise NotFound, path
    else
      raise GatewayError, "method: #{method}, path: #{path}, status: #{response.status}, body: #{response.body}"
    end
  end

  def body_to_json(body)
    case body
    when String
      body
    else
      body.to_json
    end
  end

  def parse_response(result, response_adaptor)
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
