module ArtirixDataModels::CacheService

  def self.digest_element(element)
    Digest::SHA1.hexdigest element.to_s
  end

  def self.first_options(*options, return_if_none: :default)
    key = options.detect { |x| OptionsStore.has? x }
    return OptionsStore.get(key) if key.present?

    case return_if_none
    when NilClass
      nil
    when :default
      OptionsStore.default.dup
    else
      {}
    end
  end

  def self.method_missing(m, *args, &block)
    method = m.to_s

    if KeyCleaner.valid_method method
      KeyCleaner.final_key(m, *args)

    elsif OptionsStore.valid_method method
      OptionsStore.send m, *args, &block

    elsif Expirer.valid_method method
      Expirer.send m, *args, &block

    else
      super
    end
  end

  def self.respond_to_missing?(m, include_all = false)
    method = m.to_s

    if KeyCleaner.valid_method method
      true

    elsif OptionsStore.valid_method method
      OptionsStore.respond_to? m, include_all

    elsif Expirer.valid_method method
      Expirer.respond_to? m, include_all

    else
      super
    end
  end

  private

  module KeyCleaner
    def self.valid_method(method_name)
      method_name.end_with? '_key'
    end

    def self.final_key(m, *args)
      cleaned = clean_key_section(m, *args)
      CacheStoreHelper.final_key cleaned
    end

    private
    def self.clean_key_section(key, *args)
      key_name = clean_key_name key
      a        = clean_key_args args
      suffix   = a.present? ? "/#{a}" : ''
      "#{key_name}#{suffix}"
    end

    def self.clean_key_name(key)
      key.to_s.gsub(/_key$/, '').to_sym
    end

    def self.clean_key_args(args)
      args.map { |x| x.try(:cache_key) || x.to_s }.join '/'
    end
  end

  module OptionsStore
    def self.valid_method(method_name)
      method_name.end_with? '_options'
    end

    def self.method_missing(m, *args, &block)
      if has?(m)
        get(m)
      else
        super
      end
    end

    def self.respond_to_missing?(m, include_all = false)
      has?(m) || super
    end

    private
    def self.has?(name)
      option_store.respond_to?(name)
    end

    def self.get(name)
      default.merge(get_particular(name))
    end

    def self.get_particular(name)
      Hash(option_store.send(name))
    end

    def self.default
      @default ||= Hash(option_store.default_options)
    end

    def self.option_store
      @option_store ||= SimpleConfig.for(:site).try(:cache_options) || disabled_options_store
    end

    def self.disabled_options_store
      DisabledOptionsStore.new
    end

    class DisabledOptionsStore
      def method_missing(m, *args, &block)
        {}
      end

      def respond_to_missing?(m, include_all = false)
        true
      end
    end
  end

  module Expirer
    def self.valid_method(method_name)
      method_name.start_with? 'expire_'
    end

    def self.expire_cache(pattern = nil)
      CacheStoreHelper.delete_matched(pattern)
    end
  end

  # we use `delete_matched` method -> it will work fine with Redis but it seems that it won't with Memcached
  module CacheStoreHelper
    def self.final_key(key_value)
      "#{prefix}__#{key_value}"
    end

    def self.final_pattern(pattern)
      suf = pattern.present? ? "#{pattern}*" : ''
      "*#{prefix}*#{suf}"
    end

    def self.delete_matched(pattern = nil)
      return false unless ArtirixDataModels.cache.present?
      ArtirixDataModels.cache.delete_matched final_pattern(pattern)
    end

    def self.prefix
      SimpleConfig.for(:site).try(:cache_app_prefix)
    end
  end

end
