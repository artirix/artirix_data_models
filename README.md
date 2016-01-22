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

### 0.8.0

- `DataGateway` refactor, plus adding `put` and `delete` support.

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

### 0.6.2

*Fixed Breaking Change*: removal of `Aggregation.from_json` static method. Now back but delegating to default factory method is `aggregation_factory.aggregation_from_json` in the Aggregation Factory *instance*.

- EsCollection's aggregations can now be build based on raw ElasticSearch responses, including nested aggregations. It ignores any aggregation that does not have "buckets", so that nested aggs for `global` or `filtered` are skipped and only the ones with real data are used. (TODO: write docs. In the mean time, have a look at the specs).
- added `aggregation` method to `Aggregation::Value` class, and also the aggs to the `data_hash` if they are present.

### 0.5.0

- opening gem as is to the public.
- still a lot of TODOs in the documentation


## Yanked versions

### ~0.7.0~

Yanked because of bug on Aggregations. Released 0.7.1 with the fix. Changeset moved too to 0.7.1 

### ~0.6.3~

Yanked because of typo bug on SortedBucketAggregationBase. Released 0.6.3.1 with the fix.


- Fix in EsCollection's aggregation parsing (nested + single from RAW now work ok)
- `SortedBucketAggregationBase` introduced. now `ArtirixDataModels::AggregationsFactory.sorted_aggregation_class_based_on_index_on(index_array)` available to create a class for Aggregations which will sort the buckets based on the position of the elements on a given array.


### ~0.6.1~

Yanked because of breaking change introduction: removal of `Aggregation.from_json` method

- added `aggregation` method to `Aggregation::Value` class, and also the aggs to the `data_hash` if they are present.

### ~v0.6.0~

Yanked because of breaking change introduction: removal of `Aggregation.from_json` method

- EsCollection's aggregations can now be build based on raw ElasticSearch responses, including nested aggregations. It ignores any aggregation that does not have "buckets", so that nested aggs for `global` or `filtered` are skipped and only the ones with real data are used. (TODO: write docs. In the mean time, have a look at the specs).
