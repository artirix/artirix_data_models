# ArtirixDataModels

TODO: Write a gem description

## Usage

### DAO

TODO:

### Model

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

## TODO

1. move specs to the gem
2. complete description
