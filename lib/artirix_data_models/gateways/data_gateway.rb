class ArtirixDataModels::DataGateway
  attr_reader :connection, :post_as_json

  def initialize(connection: nil,
                 post_as_json: true,
                 ensure_relative: false,
                 timeout: nil,
                 authorization_bearer: nil,
                 authorization_token_hash: nil)
    @connection               = connection || ConnectionLoader.default_connection
    @post_as_json             = !!post_as_json
    @authorization_bearer     = authorization_bearer
    @authorization_token_hash = authorization_token_hash
    @timeout                  = timeout
    @ensure_relative          = !!ensure_relative
  end

  def ensure_relative?
    !!@ensure_relative
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

  def call(method,
           path,
           json_body: true,
           response_adaptor: nil,
           body: nil,
           fake: false,
           fake_response: nil,
           cache_adaptor: nil,
           timeout: nil,
           authorization_bearer: nil,
           authorization_token_hash: nil,
           **_ignored_options)

    if fake
      result = fake_response.respond_to?(:call) ? fake_response.call : fake_response

    elsif cache_adaptor.present?
      result = cache_adaptor.call do
        perform method,
                path:                     path,
                body:                     body,
                json_body:                json_body,
                timeout:                  timeout,
                authorization_bearer:     authorization_bearer,
                authorization_token_hash: authorization_token_hash
      end

    else
      result = perform method,
                       path:                     path,
                       body:                     body,
                       json_body:                json_body,
                       timeout:                  timeout,
                       authorization_bearer:     authorization_bearer,
                       authorization_token_hash: authorization_token_hash
    end

    parse_response result:           result,
                   response_adaptor: response_adaptor,
                   method:           method,
                   path:             path
  end

  private

  def perform_get(path, **opts)
    perform :get, path: path, **opts
  end

  def perform_post(path, **opts)
    perform :post, path: path, **opts
  end

  def perform_put(path, **opts)
    perform :put, path: path, **opts
  end

  def perform_delete(path, **opts)
    perform :delete, path: path, **opts
  end

  def perform(method,
              path:,
              body: nil,
              json_body: true,
              timeout: nil,
              authorization_bearer: nil,
              authorization_token_hash: nil)

    pars = {
      path:                     path,
      body:                     body,
      json_body:                json_body,
      timeout:                  timeout,
      authorization_bearer:     authorization_bearer,
      authorization_token_hash: authorization_token_hash
    }

    response = connect(method, pars)
    treat_response(response, method, path)
  end

  # for options `timeout`, `authorization_bearer` and `authorization_token_hash`:
  # if `nil` is passed (or param is omitted) it will try to use the default passed on the gateway creation
  # but if `false` is passed, it will stay as false (can be used to override a default option passed on gateway creation)
  def connect(method,
              path:,
              body: nil,
              json_body: true,
              timeout: nil,
              authorization_bearer: nil,
              authorization_token_hash: nil)

    timeout                  = timeout.nil? ? @timeout : timeout
    authorization_bearer     = authorization_bearer.nil? ? @authorization_bearer : authorization_bearer
    authorization_token_hash = authorization_token_hash.nil? ? @authorization_token_hash : authorization_token_hash

    if ensure_relative?
      path = path.to_s.start_with?('/') ? path.to_s[1..-1] : path
    end

    connection.send(method, path) do |req|

      req.options.timeout          = timeout if timeout.present?
      req.headers['Authorization'] = Faraday::Request::Authorization.header(:Bearer, authorization_bearer) if authorization_bearer.present?
      req.headers['Authorization'] = Faraday::Request::Authorization.header(:Token, authorization_token_hash) if authorization_token_hash.present?

      unless body.nil?
        if json_body
          req.body                    = body_to_json body
          req.headers['Content-Type'] = 'application/json'
        else
          req.body = body
        end
      end
    end
  rescue Faraday::ConnectionFailed, Faraday::Error::TimeoutError, Errno::ETIMEDOUT => e
    raise ConnectionError,
          path:    path,
          method:  method,
          message: "method: #{method}, path: #{path}, error: #{e}"
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
    raise ParseError,
          path:          path,
          method:        method,
          response_body: result,
          message:       e.message
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
    raise klass,
          path:            path,
          method:          method,
          response_body:   response.body,
          response_status: response.status
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
    when 400
      BadRequest
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

  module ConnectionLoader
    class << self
      def default_connection(**others)
        connection_by_config_key :data_gateway, **others
      end

      def connection_by_config_key(config_key, **others)
        connection config: ArtirixDataModels.configuration.send(config_key), **others
      end

      def connection(config: {}, url: nil, login: nil, password: nil, bearer_token: nil, token_hash: nil)
        url          ||= config.try :url
        login        ||= config.try :login
        password     ||= config.try :password
        bearer_token ||= config.try :bearer_token
        token_hash   ||= config.try :token_hash

        raise InvalidConnectionError, 'no url given, nor is it present in `config.url`' unless url.present?

        Faraday.new(url: url, request: {params_encoder: Faraday::FlatParamsEncoder}) do |faraday|
          faraday.request :url_encoded # form-encode POST params
          faraday.response :logger # log requests to STDOUT

          if login.present? || password.present?
            faraday.basic_auth(login, password)
          elsif bearer_token.present?
            faraday.authorization :Bearer, bearer_token
          elsif token_hash.present?
            faraday.authorization :Token, token_hash
          end

          faraday.adapter Faraday.default_adapter
        end
      end
    end

    class InvalidConnectionError < StandardError
    end
  end

  class Error < StandardError
    attr_reader :path, :method, :response_status, :response_body, :message

    alias_method :msg, :message

    def initialize(*args)
      case args.size
      when 0
        message = nil
        options = {}
      when 1
        if args.first.kind_of? Hash
          options = args.first
          message = nil
        else
          message = args.first
          options = {}
        end
      else
        message = args[0]
        options = args[1]

        if message.kind_of? Hash
          options, message = message, options
        end
      end

      if message.present?
        options[:message] = message
      end

      build_from_options(options) if options.present?
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

    def message
      to_s
    end

    def data_hash
      {
        class:           self.class.to_s,
        path:            path,
        method:          method,
        response_status: response_status,
        response_body:   response_body,
        message:         message,
      }
    end

    # for testing
    def matches?(other)
      other.kind_of? self.class
    end

    private

    def build_from_options(path: nil, method: nil, response_status: nil, response_body: nil, message: nil, **_other)
      @path            = path
      @method          = method
      @response_status = response_status
      @response_body   = response_body
      @message         = message.presence || self.class.to_s
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

  # 400
  class BadRequest < GatewayError
  end

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
