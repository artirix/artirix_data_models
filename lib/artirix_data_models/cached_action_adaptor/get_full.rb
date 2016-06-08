class ArtirixDataModels::CachedActionAdaptor::GetFull < ArtirixDataModels::CachedActionAdaptor

  attr_reader :dao_name, :model

  def initialize(dao_name:, model:, **extra_options)
    @dao_name = dao_name
    @model    = model

    super(**extra_options)
  end

  private
  def cache_result(result)
    cache_write result

    if no_timestamp_mode?
      reload_cache_key_and_options # new cache key with the timestamp
      if no_timestamp_mode?
        logger.warn "IN NO TIMESTAMP MODE ON A GetFull after Reload Cache Key! #{dao_name}"
      else
        cache_write result
      end
    end
  end

  def load_cache_key
    if no_timestamp_mode?
      WithoutTimestamp.cache_key_from_model model
    else
      WithTimestamp.cache_key_from_model model
    end
  end

  def load_cache_options
    if no_timestamp_mode?
      WithoutTimestamp.cache_options dao_name
    else
      WithTimestamp.cache_options dao_name
    end
  end

  def reload_cache_key_and_options
    @cache_key         = nil
    @cache_options     = nil
    @no_timestamp_mode = nil
  end

  def no_timestamp_mode?
    return @no_timestamp_mode unless @no_timestamp_mode.nil?
    @no_timestamp_mode = model.try(:_timestamp).blank?
  end

  module WithTimestamp
    def self.cache_key_from_model(model)
      ArtirixDataModels::CacheService.key :dao_get_full, model
    end

    def self.cache_options(dao_name)
      ArtirixDataModels::CacheService.first_options "dao_#{dao_name}_get_full_options",
                                                    "dao_#{dao_name}_options",
                                                    'dao_get_full_options',
                                                    return_if_missing: :default
    end
  end

  module WithoutTimestamp
    def self.cache_key_from_model(model)
      ArtirixDataModels::CacheService.key :dao_get_full_no_time, model
    end

    def self.cache_options(dao_name)
      ArtirixDataModels::CacheService.first_options "dao_#{dao_name}_get_full_options",
                                                    "dao_#{dao_name}_get_full_no_time_options",
                                                    'dao_get_full_no_time_options',
                                                    "dao_#{dao_name}_options",
                                                    'dao_get_full_options',
                                                    return_if_missing: :default
    end
  end
end
