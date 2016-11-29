# ArtirixDataModels


[![Gem Version](https://badge.fury.io/rb/artirix_data_models.svg)](http://badge.fury.io/rb/artirix_data_models)
[![Build Status](https://travis-ci.org/artirix/artirix_data_models.svg?branch=master)](https://travis-ci.org/artirix/artirix_data_models)
[![Code Climate](https://codeclimate.com/github/artirix/artirix_data_models.png)](https://codeclimate.com/github/artirix/artirix_data_models)
[![Code Climate Coverage](https://codeclimate.com/github/artirix/artirix_data_models/coverage.png)](https://codeclimate.com/github/artirix/artirix_data_models)


This gem provides the tools for building Data Models (ActiveModel compliant objects that only receive attributes on initialisation),
with their DAOs (Data Access Objects, the ones responsible for loading them up), the EsCollection objects (collection of
objects, paginatable and with extra features), and tools that allow them to work.

Its goal is to provide a set of Read Only model objects that receive their data from some sort of Data API.

It's designed to work assuming JSON APIs and ElasticSearch responses.

# TODO:
- usage doc
- change Cache to use [artirix_cache_service](https://github.com/artirix/artirix_cache_service)


note: for making a model compatible with [ActiveModelSerializers](https://github.com/rails-api/active_model_serializers), use [artirix_data_models-ams](https://github.com/artirix/artirix_data_models-ams/)

## Usage

### Configuration

In previous versions, ADM required the use of `SimpleConfig` to configure itself. Now you have the alternative of using
`Rails.configuration` with the `config.x` support for custom configurations.

The configuration loaded will be `Rails.configuration.x.artirix_data_models` if present, or if not it will try to load
`SimpleConfig.for(:site)`. *important: it will not merge configs, it will load one or the other*

note: see [http://guides.rubyonrails.org/configuring.html#custom-configuration](http://guides.rubyonrails.org/configuring.html#custom-configuration)

You can also specify a different config by passing a config loader to `ArtirixDataModels.configuration_loader = -> { myconfig }`.

#### Using Rails config
```ruby
module SomeApplication
  class Application < Rails::Application

    # normal Rails config...
    config.action_mailer.perform_caching = false



    # ADM CONFIG
    config.x.artirix_data_models.data_gateway = ActiveSupport::OrderedOptions.new
    config.x.artirix_data_models.data_gateway.url = 'http://super-secure-domain-123456.com'
  end
end
```

#### Using SimpleConfig

```ruby
# config using SimpleConfig
SimpleConfig.for(:site) do
  group :data_gateway do
    set :url, 'http://super-secure-domain-123456.com'
  end
end
```

### Connection

You have to specify the location of data-layer. It can be done in the config like this:

```ruby
# config using Rails.configuration
config.x.artirix_data_models.data_gateway.url = 'http://super-secure-domain-123456.com'


# config using SimpleConfig
SimpleConfig.for(:site) do
  group :data_gateway do
    set :url, 'http://super-secure-domain-123456.com'
  end
end
```

If the connection is covered by basic authentication it can be set by adding ```login``` and ```password``` settings.

Example:

```ruby
SimpleConfig.for(:site) do
  group :data_gateway do
    set :url, 'http://super-secure-domain-123456.com'
    set :login, 'WhiteCat'
    set :password, 'B@dPassword!'
  end
end
```

### Model

TODO:

```ruby

class MyModel
  include ArtirixDataModels::Model::OnlyData

  attribute :id, :name

  attribute :public_title, writer_visibility: :public
  attribute :private_title, reader_visibility: :private

  attribute :remember_me, :and_me, skip: :predicate
  attribute :remember_me2, :and_me2, skip: :presence

end


```

### DAO

TODO:

### EsCollection

TODO:

#### Pagination

TODO:

### The Registry

Your app should extend the `ArtirixDataModels::DAORegistry`. We can override the `setup_config` method to add extra loaders.

**important: do not forget to call `super` on `setup_config`.**

Also, the Registry class that you want to use in your app should have in its definition a call to `self.mark_as_main_registry`. This call must be **after the override of `setup_config`.**

You can add loaders that will be called only and memoized with `set_persistent_loader` and loaders that will cbe called every time with `set_transient_loader`. `se_loader` is an alias of `set_persistent_loader`.

```ruby
class DAORegistry < ArtirixDataModels::DAORegistry
  def setup_config
    super

    set_persistent_loader(:aggregations_factory) { AggregationsFactory.new }

    set_transient_loader(:yacht) { YachtDAO.new gateway: get(:gateway) }
    set_transient_loader(:article) { ArticleDAO.new gateway: get(:gateway) }
    set_transient_loader(:broker) { BrokerDAO.new gateway: get(:gateway) }

    set_loader(:artirix_hub_api_gateway) { ArtirixDataModels::DataGateway.new connection: ArtirixHubApiService::ConnectionLoader.connection }
    set_transient_loader(:lead) { LeadDAO.new gateway: get(:artirix_hub_api_gateway) }
  end


  # AFTER defining setup_config
  self.mark_as_main_registry

end
```

You can use the DAORegistry by invoking it directly (or calling its instance) `DAORegistry.get(:name)` or `DAORegistry.instance.get(:name)`.

You can also use an identity map mode (see bellow)

### Identity Map

You can use `dao_registry = DAORegistry.with_identity_map`. Then, the DAO's default methods `get`, `find` and `get_some` will register the loaded models into the DAO, acting as an identity map, and will also use that identity map to check for the existence of models with those PKs, returning them if they are found.

The Identity Map does not have a TTL, so use it only with transient DAOs -> you don't want the identity map to live between requests, since that will mean that the models will never be forgotten, not being able to see new fresh versions, with the extra problem of memory leak.

### initializer

An initializer should be added for extra configuration.

We can enable pagination with either `will_paginate` or `kaminari`.

We can also disable cache at a lib level.

```ruby
require 'artirix_data_models'

# pagination
ArtirixDataModels::EsCollection.work_with_kaminari
# or ArtirixDataModels::EsCollection.work_with_will_paginate

#cache
ArtirixDataModels.disable_cache unless Rails.configuration.dao_cache_enabled
```


### Cache

By default all `get`, `get_full` and `get_some` calls to on a normal DAO will be cached. The response body and status of the Gateway is cached (if it is successful or a 404 error).

The cache key and the options will be determined by the cache adaptor, set by the DAO. The options are loaded from SimpleConfig, merging `default_options` with the first most specific option hash.

For example, a DAO `get` call will try to load the first options hash defined from the following list:
- "dao_#{dao_name}_get_options"
- "dao_#{dao_name}_options"
- 'dao_get_options'


example of config options (using SimpleConfig)

```
SimpleConfig.for(:site) do
  set :cache_app_prefix, 'ui'

  group :cache_options do
    group :default_options do
      set :expires_in, 15.minutes
    end

    group :dao_get_full_options do
      set :expires_in, 1.hour
    end

    group :dao_get_full_no_time_options do
      set :expires_in, 5.minutes
    end

    group :dao_yacht_get_full_options do
      set :expires_in, 15.minutes
    end
  end
end
```

Cache can be disabled at lib level with `ArtirixDataModels.disable_cache`

### Rails integration

if Rails is defined when the lib is first used, then the `logger` will be assigned to `Rails.logger` by default, and
`cache` will be `Rails.cache` by default.

### Fake Mode

TODO:

fake mode will be enabled if:

```ruby
SimpleConfig.for(:site) do
  group :data_fake_mode do
    set :article, false # NO FAKE MODE
    set :broker, false # WITH FAKE MODE
  end
end
```

### Use with RSpec

#### Custom DAO Registry

For the use of a custom DAO Registry, it is recomended to actually require it on the test helper:


in spec/rails_helper.rb:

```ruby
# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require 'rspec/given'
require 'spec_helper'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# force the use of the custom DAORegistry
require 'dao_registry'
```

#### Spec Support

add the spec support in your support files or rails_helper file:


```ruby
require 'artirix_data_models/spec_support'
```

This depends on SimpleConfig!

```ruby
SimpleConfig.for(:site) do
  group :data_gateway do
    set :url, c
  end
end
```

### FactoryGirl

In order to use FactoryGirl with these Models, we need to specify:

1. the objects cannot be saved, so we need to specify `skip_create` to avoid it.
2. the setting of the data is only to be done on the model's initialisation, not with public setters.
For that, we need to specify: `initialize_with { new(attributes) }`

```ruby

FactoryGirl.define do
  factory :article do
    # no save call
    skip_create

    # in our models we have private setters -> we need the attributes to be
    # passed on object initialisation
    initialize_with { new(attributes) }

    sequence(:id)
    title { Faker::Lorem.sentence }
  end
end
```

## TODO

1. Documentation
2. clean `basic_dao` (probably not backwards compatible, so we'll do it in a new major release)
3. use [artirix_cache_service](https://github.com/artirix/artirix_cache_service) instead of this implementation (might be not backwards compatible. If so: new major release)



## Changes

### 0.29.0

- in `DAO`, extracted the creation of the `@basic_model_dao` into a `create_basic_model_dao` method. This method can be now overridden. It accepts other params that will be passed in the object creation.

- in both `DAO` and `BasicModelDAO`, in methods `get_full`, `get`, `find` and `get_some`, we can now pass arguments `path` and `fake_response`. If the values are not passed or if they are falsey then the default generation will be used.  


### 0.28.0
- receive `faraday_build_proc` argument in `ArtirixDataModels::DataGateway::ConnectionLoader.connection`. If present, it will be passed the faraday connection before adding any configuration
```
Faraday.new(url: url, request: { params_encoder: Faraday::FlatParamsEncoder }) do |faraday|
  if faraday_build_proc.present? && faraday_build_proc.respond_to?(:call)
    faraday_build_proc.call faraday
  end

  #...
  faraday.adapter Faraday.default_adapter
end
```

### 0.27.0
- Add settings to log requests and responses bodies: `log_body_request` and `log_body_response`. Added to the `DataGateway::ConectionLoader#connection` method, and to the same config that stores ```login``` and ```password``` settings.

### 0.26.0
- Expose cache configuration in case the app has config specific for `artirix_cache_service` that we want to use with `ArtirixDataModels.use_cache_service(artirix_cache_service)` where the argument is a `ArtirixCacheService::Service` object.

### 0.25.0
- *IMPORTANT FIX*: prevent infinite loop in Model's `cache_key` method, where if `_timestamp` is nil, it will try to load `updated_at`. If that's not part of the partial mode, it will force a reload, which will get a cache_key, which will ask for `updated_at`, which will force a reload...

### 0.24.0
- add `headers` to Gateway, to Connection and to DAO methods. It expect a hash of key-value that will be passed to the Faraday call after the body of the request.

### 0.23.0
- DAORegistry now DI'ed into the DAOs and models, by adding `dao_registry_loader` or a direct `dao_registry`.
- DAORegistry with support for Identity Map
- deprecated the use of `Aggregation.from_json`, please use the factory.

### 0.22.1

added message support for DataGateway exceptions

### 0.22.0

added support for aggregations that look like 
```json
{
  "aggregations": {
    "global_published_states": {
      "doc_count": 15,
      "published_states": {
        "doc_count": 15,
        "live_soon": {
          "doc_count": 0
        },
        "draft": {
          "doc_count": 3
        },
        "expired": {
          "doc_count": 0
        },
        "live": {
          "doc_count": 12
        }
      }
    }
  }
}
```

which will be added as an aggregation like:

```ruby
es_collection.aggregations.first.name # => :published_states
es_collection.aggregations.first.buckets 
  # => [ 
  #      {name: 'live_soon', count: 0},
  #      {name: 'draft', count: 3},
  #      {name: 'expired', count: 0},
  #      {name: 'live', count: 12},
  #    ]
```

### 0.21.1

Fix bug in `Inspectable`, on Arrays. 

### 0.21.0

Changed cache to use `ArtirixCacheService` (gem `artirix_cache_service`). 

Deprecated the use of method_missing on cache in favour of the `.key` method: 

```ruby
# this is deprecated
ArtirixDataModels::CacheService.dao_get_some_key dao_name, model_pks

# in favour of this
ArtirixDataModels::CacheService.key :dao_get_some, dao_name, model_pks
```

Deprecated the key `return_if_none` on `first_options` in favour of `return_if_missing`:

```ruby
# this is deprecated
ArtirixDataModels::CacheService.first_options 'some', 'other', return_if_none: :default

# in favour of this
ArtirixDataModels::CacheService.first_options 'some', 'other', return_if_missing: :default
```


### 0.20.0
Added `ensure_relative` boolean option to the creation of a `DataGateway` (disable by default). With it enabled, it will ensure that any given `path` is relative by removing the leading `/`. This is necessary if the Gateway should call a nested endpoint and not just a host. 

Example: If we have `"http://example.org/api/"` as connection's URL, and path `"/people/1"`, with this:

- `ensure_relative = true` => it will connect to `"http://example.org/api/people/1"`
- `ensure_relative = false` (default) => it will connect to `"http://example.org/people/1"`

### 0.19.2
Added array support to `inspect`.

### 0.19.1
Added `data_hash_for_inspect` method, that will use `data_hash` by default, and have `inspect` use it.

### 0.19.0
Added `configuration_loader` and support for `Rails.configuration.x.artirix_data_models`.

### 0.18.0

`DataGateway` connection loader now moved to `DataGateway::ConnectionLoader`, with 3 public methods:
- `default_connection` which will give us the connection based on config in `data_gateway` group in `SimpleConfig.for(:site)`
- `connection_by_config_key(config_key)` which will give us the connection based on config in the given group key in `SimpleConfig.for(:site)`
- `connection(config: {}, url: nil, login: nil, password: nil, bearer_token: nil, token_hash: nil)`: It will use the elements from the given config if they are not present on the params. 

### 0.17.0

`DataGateway` now has `authorization_bearer` and `authorization_token_hash` options:
- they can be passed on the gateway creation and they will be used on all elements
- they can be overridden on a given gateway call:
-- if passed `nil` it will use the value on object creation, if present.
-- if passed `false` it will not use it (can override a value on object creation).

The values can also be added on config to the connection (but then the `false` override won't work). The authorization will be set on the connection level instead on the request level.

```ruby
SimpleConfig.for(:site) do
  group :data_gateway do
    set :token_hash, { email: 'something', token: 'whatever }
  end
end
```

```ruby
SimpleConfig.for(:site) do
  group :data_gateway do
    set :bearer_token, 'SomeBearerToken'
  end
end
```

### 0.16.0
`ArtirixDataModels::Model::CacheKey` now does not assume that you are in a complete model. It tries to use `model_dao_name`, `primary_key`, `id`, `_timestamp` and `updated_at`, but it has default for each section. Change to be able to make a model with `OnlyData` compatible with `AMS` using [`artirix_data_models-ams`](https://github.com/artirix/artirix_data_models-ams/) gem

### 0.15.1
updating dependencies: KeywordInit (to support passing nil)

### 0.15.0
- `Gateway` `perform` and `connect` now accept the extra arguments as keyword arguments:

```ruby
  gateway.perform :get, path: '/this/is/required' body: nil, json_body: true, timeout: 10 
```

The internals are adapted but if a client app was mocking Gateway's `perform` directly, this could be a breaking change.
- added the `timeout` option to perform gateway (and DAO methods). It will add timeout to the Faraday request

```ruby
def connect(method, path:, body: nil, json_body: true, timeout: nil)
  connection.send(method, path) do |req|
     req.options.timeout = timeout if timeout.present?
     # ...
  end
end
```

### 0.14.2
- Cache service: expire_cache now can receive options `add_wildcard` and `add_prefix` (both `true` by default), that will control the modifications on the given pattern

### 0.14.1
- Exceptions now with `data_hash` and ability to be raised with message, options, or both.
- Cache Adaptors now store the data hash of the NotFound exception, and a new one is built and raised when reading a cached NotFound. 

```ruby
raise ArtirixDataModels::DataGateway::NotFound, 'blah blah'
raise ArtirixDataModels::DataGateway::NotFound, path: 'something', message: 'blah blah'
raise ArtirixDataModels::DataGateway::NotFound.new('xxx')
raise ArtirixDataModels::DataGateway::NotFound.new(path: 'x')
raise ArtirixDataModels::DataGateway::NotFound.new('Something', path: 'x')
```

### 0.14.0
- `Model`: added static `mark_full_mode_by_default`: if called in the model definition it will make all new models full mode by default

```ruby
class MyModel
  include ArtirixDataModels::Model
  
  mark_full_mode_by_default
end

x = MyModel.new some: :params
x.full_mode? # => true
```

### 0.13.0
- `DAO`: fake responses lazy loaded
- `DAO`: response adaptor methods of basic dao moved to a module, included in `BasicDAO` and as part of the module `DAO`. Also added `response_adaptor_for_identity`, which returns the same.
- `Model`: added `new_full_mode` method, that will build a new model and mark it as full mode


### 0.12.0
- `attribute` call now can accept a hash of options as the last argument. This options include: `skip` (what to skip), `writer_visibility` and `reader_visibility`.

### 0.11.2
- `ArtirixDataModels::ActiveNull` better acting like a model.

### 0.11.1
- `ArtirixDataModels::DataGateway::GatewayError` subclass now for status `400`: `BadRequest`

### 0.11.0
- introducing `ArtirixDataModels::ActiveNull` with a port of `active_null` gem to work with our models.

### 0.10.1
- DAO spec helpers were broken since Gateway refactor of `v0.8`. This fixes them.

### 0.10.0

- Gateways:
-- added `gateway_factory` besides `gateway` as a creation argument for a DAO and BasicModelDAO. Now, when using a gateway in BasicModelDAO, it will use the given gateway if present, or it will call `gateway_factory.call` and use it. It won't save the result of the gateway factory, so the factory will be called every time a gateway is used.
-- `BasicModelDAO` methods can receive a `gateway` option to be used instead of the normal gateway for the particular request. Used in `_get`, `_post`, `_put` and `_delete` methods. If no override is passed, then it will use the preloaded gateway (using either `gateway` or `gateway_factory` creation arguments, see above).
-- `DAO` creation accepts an option `ignore_default_gateway` (`false` by default). If it is false, and no `gateway` or `gateway_factory` is passed, the gateway used will be `DAORegistry.gateway` (same as before). This allows to create DAOs without any gateway configured, making it necessary to instantiate it and pass it to `BasicModelDAO` on each request. 

- Response Adaptors
-- `DAO`'s `get_full` method now can pass to `BasicModelDAO` a `response_adaptor` option. `BasicModelDAO` will use `BasicModelDAO`'s `response_adaptor_for_reload` if no response adaptor is passed.
-- `DAO`'s `find` and `get` methods now can pass to `BasicModelDAO` a `response_adaptor` option. `BasicModelDAO` will use `BasicModelDAO`'s `response_adaptor_for_single` if no response adaptor is passed.
-- `DAO`'s `find` and `get_some` methods now can pass to `BasicModelDAO` a `response_adaptor` option. `BasicModelDAO` will use `BasicModelDAO`'s `response_adaptor_for_some` if no response adaptor is passed.

- `DAO`s now delegate `model_adaptor_factory` to `BasicModelDAO`
- created `IllegalActionError` error class inside of `ArtirixDataModels` module

- `ArtirixDataModels::Model` with another module `WithoutDefaultAttributes`, same as `CompleteModel` but without default attributes.

- `ArtirixDataModels::DataGateway::Error` subclass now for status `409`: `Conflict`

- in `ArtirixDataModels::DataGateway`, methods `treat_response` and `exception_for_status` are now static. They can still be used in an instance level (it delegates to class methods)

### 0.9.0

- Fake Responses now can be a callable object (if it responds to `call` it will invoke it)
- refactor in `ArtirixDataModels::DataGateway` to add more info into the exceptions
- `ArtirixDataModels::DataGateway::Error` and subclasses have now `path`, `method`, `response_status`, `response_body` (when applicable) and also `json_response_body` method which will try to parse `response_body` as if it were json (nil if it is not present or if it is not a valid json)
- `ArtirixDataModels::DataGateway::Error` subclasses now for specific response status: 
-- `NotFound`
-- `NotAcceptable` 
-- `UnprocessableEntity`
-- `Unauthorized`
-- `Forbidden`
-- `RequestTimeout`
-- `TooManyRequests`
-- `ServerError`

note: `ParseError` will not have the `response_status`

### 0.8.3

- `DataGateway` refactor, plus adding `put` and `delete` support.
- `BasicModelDAO` with `_put` and `_delete` support.
- adding gateway mock helpers for `post`, `put` and `delete`, and adapting them to the new behaviour
- including `ArtirixDataModels::Model::PublicWriters` after `ArtirixDataModels::Model::Attributes` (or after `ArtirixDataModels::Model` or `ArtirixDataModels::Model::OnlyData`) and before calling `attribute` method to make attribute writers public.

### ~0.8.0~, ~0.8.1~, ~0.8.2~ (YANKED)

Yanked because of the gateway mock helpers were missing an option, which made them not mocking properly. (moved all to `0.8.3`)

### 0.7.5

- `FakeResponseFactory` using given `_score` if > 0.

### 0.7.4

- added `~> 3.4` to the `hashie` gem dependency

### 0.7.3

- `ArtirixDataModels::FakeResponseFactory` when building a response, will try to use `hit[:_index]` and `hit[:_type]`, and use the params `index` and `document_type` if not found.

### 0.7.2

- `EsCollection` now delegates `empty?` to the results.

### 0.7.1

- added `MetricAggregation`. Normal `AggregationBuilder` will build an aggregation with that class if instead of `buckets` it finds `value` in the JSON.  
- normalize raw aggregations now does not ignore metric aggregations (see above)
- added `calculate_filtered(filtered_values)` to aggregations (noop in Metric aggregations). In a bucket aggregation, will mark with `filtered?` each bucket (aka Aggregation Value) if the `bucket.name` is present in the given `filtered_values`.
- added to `Aggregation` the methods: 
-- `filtered_buckets` that will return only buckets marked as `filtered?`
-- `unfiltered_buckets` that will return only buckets not marked as `filtered?`
-- `filtered_first_buckets` that will concatenate `filtered_buckets` and `unfiltered_buckets`
- changed classes to stop inheriting from `Struct`, had some problems with inheritance.
- `Aggregation`, `Aggregation::Value` and `MetricAggregation` now using the same inspection as models.

### ~0.7.0~ (YANKED)

Yanked because of bug on Aggregations. Released 0.7.1 with the fix. Changeset moved too to 0.7.1 

### 0.6.7

- aggregations use `key_as_string` as name of the bucket value if it exists, if not then it uses `key` and if that also does not exist then it uses `name`

### 0.6.6

- `Aggregation::Value.pretty_name` memoized and the code moved to `load_pretty_name`.

### 0.6.5

- Specify `activemodel` as a dependency and require it in the lib 
- `EsCollection` delegates `[]`, `first`, `last`, `take` and `drop` to the results.


### 0.6.4

- Add ability to create connection to data source using HTTP Basic Authentication.

### 0.6.3.1

- Fix in EsCollection's aggregation parsing (nested + single from RAW now work ok)
- `SortedBucketAggregationBase` introduced. now `ArtirixDataModels::AggregationsFactory.sorted_aggregation_class_based_on_index_on(index_array)` available to create a class for Aggregations which will sort the buckets based on the position of the elements on a given array.

### ~0.6.3~ (YANKED)

Yanked because of typo bug on SortedBucketAggregationBase. Released 0.6.3.1 with the fix.


- Fix in EsCollection's aggregation parsing (nested + single from RAW now work ok)
- `SortedBucketAggregationBase` introduced. now `ArtirixDataModels::AggregationsFactory.sorted_aggregation_class_based_on_index_on(index_array)` available to create a class for Aggregations which will sort the buckets based on the position of the elements on a given array.

### 0.6.2

*Fixed Breaking Change*: removal of `Aggregation.from_json` static method. Now back but delegating to default factory method is `aggregation_factory.aggregation_from_json` in the Aggregation Factory *instance*.

- EsCollection's aggregations can now be build based on raw ElasticSearch responses, including nested aggregations. It ignores any aggregation that does not have "buckets", so that nested aggs for `global` or `filtered` are skipped and only the ones with real data are used. (TODO: write docs. In the mean time, have a look at the specs).
- added `aggregation` method to `Aggregation::Value` class, and also the aggs to the `data_hash` if they are present.

### ~0.6.1~ (YANKED)

Yanked because of breaking change introduction: removal of `Aggregation.from_json` method

- added `aggregation` method to `Aggregation::Value` class, and also the aggs to the `data_hash` if they are present.

### ~v0.6.0~ (YANKED)

Yanked because of breaking change introduction: removal of `Aggregation.from_json` method

- EsCollection's aggregations can now be build based on raw ElasticSearch responses, including nested aggregations. It ignores any aggregation that does not have "buckets", so that nested aggs for `global` or `filtered` are skipped and only the ones with real data are used. (TODO: write docs. In the mean time, have a look at the specs).

### 0.5.0

- opening gem as is to the public.
- still a lot of TODOs in the documentation

