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
      result = fake_response.respond_to?(:call) ? fake_response.call : fake_response
    elsif cache_adaptor.present?
      result = cache_adaptor.call { perform(method, path, body, json_body) }
    else
      result = perform(method, path, body, json_body)
    end

    parse_response result:           result,
                   response_adaptor: response_adaptor,
                   method:           method,
                   path:             path
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
    raise ConnectionError.new(path: path, method: method), "method: #{method}, path: #{path}, error: #{e}"
  end

  def body_to_json(body)
    case body
    when String
      body
    else
      body.to_json
    end
  end

  def parse_response(result:, response_adaptor:, path:, method:)
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
    raise ParseError.new(path: path, method: method, response_body: result), e.message
  end

  #######################
  # EXCEPTION TREATMENT #
  #######################

  def treat_response(response, method, path)
    self.class.treat_response(response, method, path)
  end

  def exception_for_status(response_status)
    self.class.exception_for_status(response_status)
  end

  def self.treat_response(response, method, path)
    return response.body if response.success?

    klass = exception_for_status(response.status)
    raise klass.new(path: path, method: method, response_body: response.body, response_status: response.status)
  end

  def self.exception_for_status(response_status)
    case response_status.to_i
    when 404
      NotFound
    when 406
      NotAcceptable
    when 422
      UnprocessableEntity
    when 409
      Conflict
    when 401
      Unauthorized
    when 403
      Forbidden
    when 408
      RequestTimeout
    when 429
      TooManyRequests
    when 500
      ServerError
    else
      GatewayError
    end
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
    attr_reader :path, :method, :response_status, :response_body

    def initialize(path: nil, method: nil, response_status: nil, response_body: nil)
      @path            = path
      @method          = method
      @response_status = response_status
      @response_body   = response_body
    end

    def json_response_body
      return nil unless response_body.present?

      Oj.load response_body, symbol_keys: true

    rescue Oj::Error # in case it's not json
      nil
    end

    def to_s
      msg = super
      msg = nil if msg == self.class.to_s

      parts = {
        path:            path,
        method:          method,
        response_status: response_status,
        response_body:   response_body,
        message:         msg,
      }.select { |_, v| v.present? }.map { |k, v| "#{k}: #{v.inspect}" }

      "#{self.class}: #{parts.join ', '}"
    end
  end

  class ParseError < Error
  end

  class GatewayError < Error
  end

  ###########################################
  # SPECIAL, not subclasses of GatewayError #
  ###########################################

  # 404
  class NotFound < Error
  end

  # 406
  class NotAcceptable < Error
  end

  # 422
  class UnprocessableEntity < Error
  end

  # 409
  class Conflict < Error
  end

  ##############################
  # subclasses of GatewayError #
  ##############################

  # 401
  class Unauthorized < GatewayError
  end

  # 403
  class Forbidden < GatewayError
  end

  # 408
  class RequestTimeout < GatewayError
  end

  # 429
  class TooManyRequests < GatewayError
  end

  # 500
  class ServerError < GatewayError
  end

  # generic error
  class ConnectionError < GatewayError
  end
end
