module ArtirixDataModels::WithDAORegistry
  DEFAULT_DAO_REGISTRY_LOADER = ->() { ArtirixDataModels::DAORegistry.instance }

  # set_xxx* methods can be chained (return self)
  # xxx= methods return the value set

  def dao_registry
    dao_registry_loader.call
  end

  def dao_registry_loader
    @dao_registry_loader || DEFAULT_DAO_REGISTRY_LOADER
  end

  attr_writer :dao_registry_loader

  def set_dao_registry_loader(dao_registry_loader)
    self.dao_registry_loader = dao_registry_loader
    self
  end

  def dao_registry=(dao_registry)
    if dao_registry
      set_dao_registry_loader ->() { dao_registry }
    else
      set_default_dao_registry_loader
    end

    dao_registry
  end

  def set_dao_registry(dao_registry)
    self.dao_registry = dao_registry
    self
  end

  def default_dao_registry
    DEFAULT_DAO_REGISTRY_LOADER.call
  end

  def set_default_dao_registry_loader
    @dao_registry_loader = nil
    self
  end

  alias_method :set_default_dao_registry, :set_default_dao_registry_loader

  # will use the loader if present, if not it will use the registry, if not present it will do nothing.
  def set_dao_registry_and_loader(loader, registry)
    raise ArgumentError, 'loader has to respond to :call' if loader.present? && !loader.respond_to?(:call)

    if loader.respond_to? :call
      set_dao_registry_loader loader
    elsif registry
      set_dao_registry registry
    end

    self
  end

end