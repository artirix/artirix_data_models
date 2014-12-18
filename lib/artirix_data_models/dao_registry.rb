class ArtirixDataModels::DAORegistry
  include Singleton

  # singleton instance
  def initialize
    @_repository = {}
    @_loaders    = {}
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
    @_repository.key?(key) || @_loaders.key?(key)
  end

  def get(key)
    @_repository[key.to_sym] || call_loader(key)
  end

  def call_loader(key)
    key               = key.to_sym
    @_repository[key] = @_loaders[key].call
  end

  def set_loader(key, loader = nil, &block)
    key = key.to_sym

    if block
      @_loaders[key] = block
    elsif loader.respond_to? :call
      @_loaders[key] = loader
    else
      raise ArgumentError, "no block and no loader given for key #{key}"
    end
  end

  # static methods

  def self.set_loader(key, loader = nil, &block)
    instance.set_loader key, loader, &block
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


  set_loader(:basic_class) { ArtirixDataModels::BasicModelDAO }
  set_loader(:gateway) { ArtirixDataModels::DataGateway.new }
  set_loader(:model_fields) { ArtirixDataModels::ModelFieldsDAO.new gateway: get(:gateway) }

end