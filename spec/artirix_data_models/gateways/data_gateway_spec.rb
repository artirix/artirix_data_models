require 'spec_helper'

RSpec.describe ArtirixDataModels::DataGateway, type: :model do
  describe '.new' do
    context 'without connection' do
      Given(:connection_url) { 'http://example.com/other' }

      Given do
        c = connection_url
        SimpleConfig.for(:site) do
          group :data_gateway do
            set :url, c
          end
        end
      end

      When(:gateway) { described_class.new }
      Then { gateway.connection.url_prefix.to_s == connection_url }
    end

    context 'basic auth connection' do
      Given(:connection_url) { 'http://example.com/other' }
      Given(:basic_login)    { 'WhiteCat' }
      Given(:basic_password) { 'B@dPassword!' }

      Given do
        url      = connection_url
        login    = basic_login
        password = basic_password

        SimpleConfig.for(:site) do
          group :data_gateway do
            set :url, url
            set :login, login
            set :password, password
          end
        end
      end

      When(:gateway) { described_class.new }
      Then { expect(gateway.connection.url_prefix.to_s).to eq(connection_url) }
      Then { expect(gateway.connection.headers).to have_key('Authorization') }
    end
  end

  context 'requests with timeout' do
    Given(:connection_url) { 'http://10.255.255.1' }
    Given(:connection) do
      Faraday.new(url: connection_url, request: { params_encoder: Faraday::FlatParamsEncoder }) do |faraday|
        faraday.request :url_encoded # form-encode without body only path params
        faraday.response :logger # log requests to STDOUT
        faraday.adapter Faraday.default_adapter
      end
    end

    Given(:gateway) do
      described_class.new connection: connection
    end

    Given(:path_with_timeout) { '/anywhere' }

    describe '#get' do
      When(:result) { gateway.get path_with_timeout, timeout: 1 }

      Then { result == Failure(ArtirixDataModels::DataGateway::ConnectionError) }
    end
  end

  context 'requests' do
    Given(:connection_url) { 'http://example.com' }
    Given(:connection_stubs) { Faraday::Adapter::Test::Stubs.new }
    Given(:connection) do
      Faraday.new(url: connection_url, request: { params_encoder: Faraday::FlatParamsEncoder }) do |faraday|
        faraday.request :url_encoded # form-encode without body only path params
        faraday.response :logger # log requests to STDOUT
        faraday.adapter :test, connection_stubs
      end
    end
    Given(:gateway) do
      described_class.new connection: connection
    end

    context 'calling' do
      Given(:path) { '/somepath' }
      Given(:body) { nil }
      Given(:test_json) { '{"some": "json"}' }
      Given(:test_hash) { Oj.load test_json, symbol_keys: true }

      Given(:response_string) { test_json }
      Given(:response_hash) { Oj.load response_string, symbol_keys: true }

      Given(:path_to_fail) { '/to-fail' }
      Given(:path_to_be_not_found) { '/to-be-not-found' }
      Given(:path_to_be_bad_json) { '/to-be-bad-json' }
      Given(:path_to_be_empty) { '/to-be-empty' }


      # A callable object that will return a JSON string with the body embedded
      Given(:response_string_with_body) do
        ->(body) { "{\"body\": #{body}}" }
      end

      Given do
        # stub gets
        connection_stubs.get(path) do |env|
          if env.body.nil?
            # TO STUB REQUEST WITHOUT BODY
            response_body = response_string
          else
            # TO STUB REQUEST WITH BODY
            response_body = response_string_with_body.call(env.body)
          end

          [200, {}, response_body]
        end

        connection_stubs.get(path_to_be_not_found) { |env| [404, {}, ''] }
        connection_stubs.get(path_to_fail) { |env| [500, {}, ''] }
        connection_stubs.get(path_to_be_bad_json) { |env| [200, {}, 'oh yeah'] }
        connection_stubs.get(path_to_be_empty) { |env| [200, {}, ''] }

        # stub posts
        connection_stubs.post(path_to_be_not_found) { |env| [404, {}, ''] }
        connection_stubs.post(path_to_fail) { |env| [500, {}, ''] }
        connection_stubs.post(path_to_be_bad_json) { |env| [200, {}, 'oh yeah'] }
        connection_stubs.post(path_to_be_empty) { |env| [200, {}, ''] }

        # stub put
        connection_stubs.put(path_to_be_not_found) { |env| [404, {}, ''] }
        connection_stubs.put(path_to_fail) { |env| [500, {}, ''] }
        connection_stubs.put(path_to_be_bad_json) { |env| [200, {}, 'oh yeah'] }
        connection_stubs.put(path_to_be_empty) { |env| [200, {}, ''] }

        # stub put
        connection_stubs.delete(path_to_be_not_found) { |env| [404, {}, ''] }
        connection_stubs.delete(path_to_fail) { |env| [500, {}, ''] }
        connection_stubs.delete(path_to_be_bad_json) { |env| [200, {}, 'oh yeah'] }
        connection_stubs.delete(path_to_be_empty) { |env| [200, {}, ''] }
      end

      describe '#get' do
        context 'when failure (500 error)' do
          When(:result) { gateway.get path_to_fail }
          Then { result == Failure(ArtirixDataModels::DataGateway::GatewayError) }
        end

        context 'when not found (404 error)' do
          When(:result) { gateway.get path_to_be_not_found }
          Then { result == Failure(ArtirixDataModels::DataGateway::NotFound) }
        end

        context 'when receiving bad json' do
          When(:result) { gateway.get path_to_be_bad_json }
          Then { result == Failure(ArtirixDataModels::DataGateway::ParseError) }
        end

        context 'when receiving empty response' do
          When(:result) { gateway.get path_to_be_empty }
          Then { result.nil? }
        end

        context 'only path given -> return parsed response (JSON -> Hash)' do
          When(:result) { gateway.get path }
          Then { result == response_hash }
        end

        context 'with adaptor -> call the adaptor with the parsed response (JSON -> Hash -> AdaptedObject)' do
          Given(:model_class) do
            Class.new do
              attr_reader :data

              def initialize(data)
                @data = { given: data }
              end
            end
          end

          Given(:adaptor) { ArtirixDataModels::GatewayResponseAdaptors::ModelAdaptor.single model_class }

          When(:result) { gateway.get path, response_adaptor: adaptor }
          Then { result.class == model_class }
          And { result.data == { given: response_hash } }
        end

        context 'with body' do
          Given(:body) { test_hash }

          context 'STRING body => use body as is' do
            When(:result) { gateway.get path, body: body.to_json }
            Then { result == { body: test_hash } }
          end

          context 'object (or hash) body => use body.to_json' do
            When(:result) { gateway.get path, body: body }
            Then { result == { body: test_hash } }
          end
        end
      end

      describe '#post' do
        context 'without body' do
          Given do
            connection_stubs.post(path, nil) do |env|
              [200, {}, response_string]
            end
          end

          context 'when failure (500 error)' do
            When(:result) { gateway.post path_to_fail }
            Then { result == Failure(ArtirixDataModels::DataGateway::GatewayError) }
          end

          context 'when not found (404 error)' do
            When(:result) { gateway.post path_to_be_not_found }
            Then { result == Failure(ArtirixDataModels::DataGateway::NotFound) }
          end

          context 'when receiving bad json' do
            When(:result) { gateway.post path_to_be_bad_json }
            Then { result == Failure(ArtirixDataModels::DataGateway::ParseError) }
          end

          context 'when receiving empty response' do
            When(:result) { gateway.post path_to_be_empty }
            Then { result.nil? }
          end

          context 'only path given -> return parsed response (JSON -> Hash)' do
            When(:result) { gateway.post path }
            Then { result == response_hash }
          end

          context 'with adaptor -> call the adaptor with the parsed response (JSON -> Hash -> AdaptedObject)' do
            Given(:model_class) do
              Class.new do
                attr_reader :data

                def initialize(data)
                  @data = { given: data }
                end
              end
            end

            Given(:adaptor) { ArtirixDataModels::GatewayResponseAdaptors::ModelAdaptor.single model_class }

            When(:result) { gateway.get path, response_adaptor: adaptor }
            Then { result.class == model_class }
            And { result.data == { given: response_hash } }
          end

        end
        context 'with body', focus: true do
          Given(:body) { test_hash }
          Given(:body_json) { body.to_json }

          Given do
            connection_stubs.post(path, body_json, { 'Content-Type' => 'application/json' }) do
              response_body = response_string_with_body.call(body_json)
              [200, {}, response_body]
            end
          end

          context 'STRING body => use body as is' do
            When(:result) { gateway.post path, body: body_json }
            Then { result == { body: test_hash } }
          end

          context 'object (or hash) body => use body.to_json' do
            When(:result) { gateway.post path, body: body }
            Then { result == { body: test_hash } }
          end
        end
      end

      describe '#put' do
        context 'without body' do
          Given do
            connection_stubs.put(path, nil) do |env|
              [200, {}, response_string]
            end
          end

          context 'when failure (500 error)' do
            When(:result) { gateway.put path_to_fail }
            Then { result == Failure(ArtirixDataModels::DataGateway::GatewayError) }
          end

          context 'when not found (404 error)' do
            When(:result) { gateway.put path_to_be_not_found }
            Then { result == Failure(ArtirixDataModels::DataGateway::NotFound) }
          end

          context 'when receiving bad json' do
            When(:result) { gateway.put path_to_be_bad_json }
            Then { result == Failure(ArtirixDataModels::DataGateway::ParseError) }
          end

          context 'when receiving empty response' do
            When(:result) { gateway.put path_to_be_empty }
            Then { result.nil? }
          end

          context 'only path given -> return parsed response (JSON -> Hash)' do
            When(:result) { gateway.put path }
            Then { result == response_hash }
          end

          context 'with adaptor -> call the adaptor with the parsed response (JSON -> Hash -> AdaptedObject)' do
            Given(:model_class) do
              Class.new do
                attr_reader :data

                def initialize(data)
                  @data = { given: data }
                end
              end
            end

            Given(:adaptor) { ArtirixDataModels::GatewayResponseAdaptors::ModelAdaptor.single model_class }

            When(:result) { gateway.get path, response_adaptor: adaptor }
            Then { result.class == model_class }
            And { result.data == { given: response_hash } }
          end

        end
        context 'with body', focus: true do
          Given(:body) { test_hash }
          Given(:body_json) { body.to_json }

          Given do
            connection_stubs.put(path, body_json, { 'Content-Type' => 'application/json' }) do
              response_body = response_string_with_body.call(body_json)
              [200, {}, response_body]
            end
          end

          context 'STRING body => use body as is' do
            When(:result) { gateway.put path, body: body_json }
            Then { result == { body: test_hash } }
          end

          context 'object (or hash) body => use body.to_json' do
            When(:result) { gateway.put path, body: body }
            Then { result == { body: test_hash } }
          end
        end
      end

      describe '#delete' do
        Given do
          connection_stubs.delete(path) do |env|
            [200, {}, response_string]
          end
        end

        context 'when failure (500 error)' do
          When(:result) { gateway.delete path_to_fail }
          Then { result == Failure(ArtirixDataModels::DataGateway::GatewayError) }
        end

        context 'when not found (404 error)' do
          When(:result) { gateway.delete path_to_be_not_found }
          Then { result == Failure(ArtirixDataModels::DataGateway::NotFound) }
        end

        context 'when receiving bad json' do
          When(:result) { gateway.delete path_to_be_bad_json }
          Then { result == Failure(ArtirixDataModels::DataGateway::ParseError) }
        end

        context 'when receiving empty response' do
          When(:result) { gateway.delete path_to_be_empty }
          Then { result.nil? }
        end

        context 'only path given -> return parsed response (JSON -> Hash)' do
          When(:result) { gateway.delete path }
          Then { result == response_hash }
        end

        context 'with adaptor -> call the adaptor with the parsed response (JSON -> Hash -> AdaptedObject)' do
          Given(:model_class) do
            Class.new do
              attr_reader :data

              def initialize(data)
                @data = { given: data }
              end
            end
          end

          Given(:adaptor) { ArtirixDataModels::GatewayResponseAdaptors::ModelAdaptor.single model_class }

          When(:result) { gateway.delete path, response_adaptor: adaptor }
          Then { result.class == model_class }
          And { result.data == { given: response_hash } }
        end
      end
    end
  end

end
