module ArtirixDataModels::WithDAORegistry
  DEFAULT_DAO_REGISTRY_LOADER = ->() { ArtirixDataModels::DAORegistry.instance }

  def self.loader_or_registry_or_default(dao_registry: nil, dao_registry_loader: nil)
    raise ArgumentError, 'loader has to respond to :call' if dao_registry_loader.present? && !dao_registry_loader.respond_to?(:call)

    if dao_registry_loader.respond_to? :call
      dao_registry_loader.call
    elsif dao_registry
      dao_registry
    else
      DEFAULT_DAO_REGISTRY_LOADER.call
    end
  end

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
  def set_dao_registry_and_loader(dao_registry_loader, dao_registry)
    raise ArgumentError, 'loader has to respond to :call' if dao_registry_loader.present? && !dao_registry_loader.respond_to?(:call)

    if dao_registry_loader.respond_to? :call
      set_dao_registry_loader dao_registry_loader
    elsif dao_registry
      set_dao_registry dao_registry
    end

    self
  end

end