module ArtirixDataModels::CacheService
  def self.reload_service
    @service = nil
    service
  end

  def self.service
    @service ||= ArtirixCacheService::Service.new.tap do |service|
      prefix = ArtirixDataModels.configuration.try(:cache_app_prefix)
      if prefix
        service.register_key_prefix "#{prefix}__"
      end

      options = ArtirixDataModels.configuration.try(:cache_options)
      if options
        options.each do |name, opts|
          if name.to_s == 'default_options'
            service.register_default_options opts
          else
            service.register_options name, opts
          end
        end
      end

    end
  end

  def self.digest_element(element)
    service.digest element
  end

  def self.first_options(*options, return_if_missing: :default, **opts)
    if opts.key? :return_if_none
      ActiveSupport::Deprecation.warn('use `return_if_missing` instead of `return_if_none`')
      return_if_missing = opts[:return_if_none]
    end

    service.options *options, return_if_missing: return_if_missing
  end

  def self.key(*given_args)
    service.key *given_args
  end

  def self.options(options_name)
    service.registered_options options_name
  end

  def self.options?(options_name)
    service.registered_options? options_name
  end

  # we use `delete_matched` method -> it will work fine with Redis but it seems that it won't with Memcached
  def self.expire_cache(pattern = nil, add_wildcard: true, add_prefix: true)
    return false unless ArtirixDataModels.cache.present?

    p = final_pattern(pattern, add_wildcard: add_wildcard, add_prefix: add_prefix)

    ArtirixDataModels.cache.delete_matched p
  end

  def self.final_pattern(pattern, add_wildcard: true, add_prefix: true)
    p = pattern
    p = p.present? ? "#{p}*" : '' if add_wildcard
    p = "*#{service.key_prefix}*#{p}" if add_prefix
    p
  end


  def self.method_missing(m, *args, &block)
    method = m.to_s

    if method.end_with? '_key'
      ActiveSupport::Deprecation.warn('using method_missing with `service.some_key("1", "2")` is deprecated, use this instead: `service.key(:some, "1", "2")`')
      key = method.gsub(/_key$/, '')
      self.key key, *args

    elsif method.end_with? '_options'
      ActiveSupport::Deprecation.warn('using method_missing with `service.some_options` is deprecated, use this instead: `service.options(:some)`')
      options_name = method.gsub(/_options$/, '')
      self.options options_name

    else
      super
    end
  end

  def self.respond_to_missing?(m, include_all = false)
    method = m.to_s

    if method.end_with? '_key'
      ActiveSupport::Deprecation.warn('using method_missing with `service.some_key("1", "2")` is deprecated, use this instead: `service.key(:some, "1", "2")`')
      true

    elsif method.end_with? '_options'
      ActiveSupport::Deprecation.warn('using method_missing with `service.some_options` is deprecated, use this instead: `service.options(:some)`')
      options_name = method.gsub(/_options$/, '')
      self.options options_name

    else
      super
    end
  end
end
