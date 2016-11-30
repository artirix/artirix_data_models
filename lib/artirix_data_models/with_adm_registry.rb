module ArtirixDataModels::WithADMRegistry
  DEFAULT_DAO_REGISTRY_LOADER = ->() { ArtirixDataModels::ADMRegistry.instance }

  def self.loader_or_registry_or_default(adm_registry: nil, adm_registry_loader: nil)
    raise ArgumentError, 'loader has to respond to :call' if adm_registry_loader.present? && !adm_registry_loader.respond_to?(:call)

    if adm_registry_loader.respond_to? :call
      adm_registry_loader.call
    elsif adm_registry
      adm_registry
    else
      DEFAULT_DAO_REGISTRY_LOADER.call
    end
  end

  # set_xxx* methods can be chained (return self)
  # xxx= methods return the value set

  def adm_registry
    adm_registry_loader.call
  end

  def adm_registry_loader
    @adm_registry_loader || DEFAULT_DAO_REGISTRY_LOADER
  end

  attr_writer :adm_registry_loader

  def set_adm_registry_loader(adm_registry_loader)
    self.adm_registry_loader = adm_registry_loader
    self
  end

  def adm_registry=(adm_registry)
    if adm_registry
      set_adm_registry_loader ->() { adm_registry }
    else
      set_default_adm_registry_loader
    end

    adm_registry
  end

  def set_adm_registry(adm_registry)
    self.adm_registry = adm_registry
    self
  end

  def default_adm_registry
    DEFAULT_DAO_REGISTRY_LOADER.call
  end

  def set_default_adm_registry_loader
    @adm_registry_loader = nil
    self
  end

  alias_method :set_default_adm_registry, :set_default_adm_registry_loader

  # will use the loader if present, if not it will use the registry, if not present it will do nothing.
  def set_adm_registry_and_loader(adm_registry_loader, adm_registry)
    raise ArgumentError, 'loader has to respond to :call' if adm_registry_loader.present? && !adm_registry_loader.respond_to?(:call)

    if adm_registry_loader.respond_to? :call
      set_adm_registry_loader adm_registry_loader
    elsif adm_registry
      set_adm_registry adm_registry
    end

    self
  end

end