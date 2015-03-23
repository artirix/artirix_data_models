# ArtirixDataModels

TODO: Write a gem description

## Usage

TODO: move

### initializer
an initializer should be added for adding DAOs to the registry and for enabling pagination with either `will_paginate`
or `kaminari`

```
# add new DAOs
ArtirixDataModels::DAORegistry.tap do |reg|
  reg.set_loader(:cms_yacht) { DataDAO::YachtDAO.new gateway: reg.gateway }
  reg.set_loader(:cms_sale_listing) { DataDAO::SaleListingDAO.new gateway: reg.gateway }
  reg.set_loader(:cms_charter_listing) { DataDAO::CharterListingDAO.new gateway: reg.gateway }
end

ArtirixDataModels::EsCollection.work_with_will_paginate
# or ArtirixDataModels::EsCollection.work_with_kaminari
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
