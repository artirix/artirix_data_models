require "artirix_data_models/version"

# dependencies
require 'active_support/all'
require 'simple_config'
require 'oj'
require 'faraday'
require 'keyword_init'

# note DO NOT require kaminari or will_paginate, it'll be done when invoking `ArtirixDataModels::EsCollection.work_with_will_paginate`


# loading features
require 'artirix_data_models/es_collection'
require 'artirix_data_models/aggregations_factory'
require 'artirix_data_models/aggregation'
require 'artirix_data_models/model'
require 'artirix_data_models/gateways/data_gateway'
require 'artirix_data_models/gateway_response_adaptors/model_adaptor'
require 'artirix_data_models/dao'
require 'artirix_data_models/daos/model_fields_dao'
require 'artirix_data_models/daos/basic_model_dao'
require 'artirix_data_models/dao_registry'
require 'artirix_data_models/fake_response_factory'

module ArtirixDataModels
end
