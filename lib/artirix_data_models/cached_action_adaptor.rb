class ArtirixDataModels::CachedActionAdaptor
  STATUS_OK        = 'ok'.freeze
  STATUS_NOT_FOUND = 'not_found'.freeze
  STATUSES         = [STATUS_OK, STATUS_NOT_FOUND]

  attr_reader :logger, :cache

  def initialize(logger: nil, cache: nil, **ignored_options)
    @logger  = logger || ArtirixDataModels.logger
    @cache   = cache || ArtirixDataModels.cache
    @enabled = true
  end

  def cached?
    return false unless enabled?

    cache_exist?
  end

  def fetch(&block)
    if cached?
      get_cached_result
    elsif block_given?
      perform &block
    else
      nil
    end
  end

  alias_method :call, :fetch

  def enable
    @enabled = true
  end

  def disable
    @enabled = false
  end

  def enabled?
    @enabled
  end

  private

  def get_cached_result
    return nil unless enabled?

    c = cache_read
    return nil unless c.present?
    return c unless c.respond_to?(:size) && c.respond_to?(:first) && c.size == 2 && STATUSES.include?(c.first)

    status = c.first
    result = c.last

    case status
    when STATUS_NOT_FOUND
      raise ArtirixDataModels::DataGateway::NotFound, result
    else
      result
    end
  end

  def perform
    return yield unless enabled?

    result = yield
    cache_result [STATUS_OK, result]
    result
  rescue ArtirixDataModels::DataGateway::NotFound => e
    cache_result [STATUS_NOT_FOUND, e.message]
    raise e
  end

  def cache_result(result)
    cache_write result
  end

  def load_cache_key
    raise NotImplementedError
  end

  def load_cache_options
    raise NotImplementedError
  end

  def cache_key
    @cache_key ||= load_cache_key
  end

  def cache_options
    @cache_options ||= load_cache_options
  end

  def cache_exist?
    logger.debug "EXIST CACHE with key #{cache_key.inspect}"
    return false unless cache.present?

    cache.exist? cache_key, cache_options
  end


  def cache_read
    logger.debug "READ CACHE with key #{cache_key.inspect}"
    return nil unless cache.present?

    cache.read cache_key, cache_options
  end

  def cache_write(value)
    logger.debug "WRITE CACHE with key #{cache_key.inspect}"
    return value unless cache.present?

    cache.write cache_key, value, cache_options
    value
  end

end
