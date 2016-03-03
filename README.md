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


## Usage

### Connection

You have to specify the location of data-layer. It can be done in the config like this:

```ruby
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

```ruby
class DAORegistry < ArtirixDataModels::DAORegistry
  def setup_config
    super

    set_loader(:aggregations_factory) { AggregationsFactory.new }

    set_loader(:yacht) { YachtDAO.new gateway: get(:gateway) }
    set_loader(:article) { ArticleDAO.new gateway: get(:gateway) }
    set_loader(:broker) { BrokerDAO.new gateway: get(:gateway) }

    set_loader(:artirix_hub_api_gateway) { ArtirixDataModels::DataGateway.new connection: ArtirixHubApiService::ConnectionLoader.connection }
    set_loader(:lead) { LeadDAO.new gateway: get(:artirix_hub_api_gateway) }
  end


  # AFTER defining setup_config
  self.mark_as_main_registry

end
```

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

