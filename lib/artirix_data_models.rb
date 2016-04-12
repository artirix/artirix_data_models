require 'artirix_data_models/version'

# dependencies
require 'active_support/all'
require 'active_model'
require 'oj'
require 'faraday'
require 'keyword_init'
require 'naught'
require 'hashie'

# note DO NOT require kaminari or will_paginate, it'll be done when invoking `ArtirixDataModels::EsCollection.work_with_will_paginate`
# note: do not require SimpleConfig, it has to exist before used. Same as we don't require Rails.


# loading features
require 'artirix_data_models/inspectable'
require 'artirix_data_models/es_collection'
require 'artirix_data_models/aggregation'
require 'artirix_data_models/aggregations_factory'
require 'artirix_data_models/raw_aggregation_data_normaliser'
require 'artirix_data_models/aggregation_builder'
require 'artirix_data_models/model'
require 'artirix_data_models/gateways/data_gateway'
require 'artirix_data_models/gateway_response_adaptors/model_adaptor'
require 'artirix_data_models/cache_service'
require 'artirix_data_models/cached_action_adaptor'
require 'artirix_data_models/cached_action_adaptor/get'
require 'artirix_data_models/cached_action_adaptor/get_full'
require 'artirix_data_models/cached_action_adaptor/get_some'
require 'artirix_data_models/dao_concerns/with_response_adaptors'
require 'artirix_data_models/dao'
require 'artirix_data_models/daos/model_fields_dao'
require 'artirix_data_models/daos/basic_model_dao'
require 'artirix_data_models/dao_registry'
require 'artirix_data_models/fake_response_factory'
require 'artirix_data_models/active_null'

module ArtirixDataModels

  # internal Classes
  DisabledLogger = Naught.build do |config|
    config.black_hole
  end

  DisabledCache = Naught.build do |config|
    config.black_hole

    def enabled?
      false
    end

    def exist?(*)
      false
    end

    def write(cache_key, value, *_)
      value
    end
  end

  # LOGGER
  def self.logger
    logger_loader.call
  end

  def self.logger_loader=(loader=nil, &block)
    if block_given?
      @logger_loader = block
    elsif loader.present? && loader.respond_to?(:call)
      @logger_loader = loader
    else
      raise 'no block or callable object given as a loader'
    end
  end

  def self.logger_loader
    @logger_loader ||= default_logger_loader
  end

  def self.default_logger_loader
    lambda { defined?(Rails) ? Rails.logger : disabled_logger }
  end

  def self.logger=(logger)
    @logger_loader = -> { logger }
  end

  def self.disable_logger
    @logger_loader = -> { disabled_logger }
  end

  def self.disabled_logger
    @disabled_logger ||= DisabledLogger.new
  end

  # CACHE

  def self.cache
    cache_loader.call
  end

  def self.cache_loader=(loader=nil, &block)
    if block_given?
      @cache_loader = block
    elsif loader.present? && loader.respond_to?(:call)
      @cache_loader = loader
    else
      raise 'no block or callable object given as a loader'
    end
  end

  def self.cache_loader
    @cache_loader ||= default_cache_loader
  end

  def self.default_cache_loader
    lambda { defined?(Rails) ? Rails.cache : disabled_cache }
  end

  def self.cache=(cache)
    @cache_loader = -> { cache }
  end

  def self.disable_cache
    @cache_loader = -> { disabled_cache }
  end

  def self.disabled_cache
    @disabled_cache ||= DisabledCache.new
  end

  # CONFIGURATION

  def self.configuration
    configuration_loader.call
  end

  def self.configuration_loader=(loader=nil, &block)
    if block_given?
      @configuration_loader = block
    elsif loader.present? && loader.respond_to?(:call)
      @configuration_loader = loader
    else
      raise 'no block or callable object given as a loader'
    end
  end

  def self.configuration_loader
    @configuration_loader ||= default_configuration_loader
  end

  def self.default_configuration_loader
    lambda do
      if defined?(Rails) && Rails.configuration.try(:x) && Rails.configuration.x.artirix_data_models.present?
        Rails.configuration.x.artirix_data_models
      elsif defined?(SimpleConfig)
        SimpleConfig.for(:site)
      else
        raise ConfigurationNeededError, 'Rails.configuration.x.artirix_data_models not available, and SimpleConfig.for(:site) not available'
      end
    end
  end

  class IllegalActionError < StandardError
  end

  class ConfigurationNeededError < StandardError
  end

end
