class ArtirixDataModels::DAORegistry

  def self.instance
    @__instance ||= new
  end

  def self.instance=(x)
    @__instance = x
  end

  def self.mark_as_main_registry
    ArtirixDataModels::DAORegistry.instance = self.instance
  end

  # singleton instance
  def initialize
    @_repository         = {}
    @_persistent_loaders = {}
    @_transient_loaders  = {}

    setup_config
  end

  def setup_config
    set_persistent_loader(:aggregations_factory) { ArtirixDataModels::AggregationsFactory.new }
    set_persistent_loader(:basic_class) { ArtirixDataModels::BasicModelDAO }
    set_persistent_loader(:gateway) { ArtirixDataModels::DataGateway.new }
    set_persistent_loader(:model_fields) { ArtirixDataModels::ModelFieldsDAO.new gateway: get(:gateway) }
  end

  def aggregations_factory
    get :aggregations_factory
  end

  def method_missing(method, *args, &block)
    if exist?(method)
      get(method)
    else
      super
    end
  end

  def respond_to_missing?(method, _ = false)
    exist?(method) || super
  end

  def exist?(key)
    key = key.to_sym
    @_repository.key?(key) || @_persistent_loaders.key?(key) || @_transient_loaders.key?(key)
  end

  def get(key)
    @_repository[key.to_sym] || get_from_loader(key)
  end

  def set_transient_loader(key, loader = nil, &block)
    key = key.to_sym

    if block
      @_transient_loaders[key] = block
    elsif loader.respond_to? :call
      @_transient_loaders[key] = loader
    else
      raise ArgumentError, "no block and no loader given for key #{key}"
    end
  end

  def set_persistent_loader(key, loader = nil, &block)
    key = key.to_sym

    if block
      @_persistent_loaders[key] = block
    elsif loader.respond_to? :call
      @_persistent_loaders[key] = loader
    else
      raise ArgumentError, "no block and no loader given for key #{key}"
    end
  end

  alias_method :set_loader, :set_persistent_loader

  private
  def get_from_loader(key)
    call_loader(key).tap do |object|
      object.try :set_dao_registry, self
    end
  end

  def call_loader(key)
    key = key.to_sym
    if @_persistent_loaders[key]
      @_repository[key] = @_persistent_loaders[key].call
    elsif @_transient_loaders[key]
      @_transient_loaders[key].call
    else
      raise LoaderNotFound, "no loader or transient found for #{key}"
    end
  end


  # static methods

  def self.set_loader(key, loader = nil, &block)
    instance.set_loader key, loader, &block
  end

  def self.set_persistent_loader(key, loader = nil, &block)
    instance.set_persistent_loader key, loader, &block
  end

  def self.set_transient_loader(key, loader = nil, &block)
    instance.set_transient_loader key, loader, &block
  end

  def self.get(key)
    instance.get key
  end

  def self.exist?(key)
    instance.exist? key
  end

  def self.method_missing(method, *args, &block)
    if exist?(method)
      get(method)
    else
      super
    end
  end

  def self.respond_to_missing?(method, include_all = false)
    exist?(method) || super
  end

  class LoaderNotFound < StandardError
  end


end