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

  def get(key, override_dao_registry: nil)
    x = @_repository[key.to_sym] || call_loader(key)
    if x.present? && override_dao_registry.present? && x.respond_to?(:set_dao_registry)
      x.set_dao_registry override_dao_registry
    end

    x
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

  ################
  # IDENTITY MAP #
  ################

  def with_identity_map
    IdentityMap.new dao_registry: self
  end

  # IDENTITY MAP compatible
  def register_model(_model)
    # DO NOTHING
    self
  end

  def unload_model(_model)
    # DO NOTHING
    self
  end

  def get_model(_model_dao_name, _primary_key)
    # DO NOTHING
    nil
  end

  private
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

  def self.with_identity_map
    instance.with_identity_map
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

  class IdentityMap
    include ArtirixDataModels::WithDAORegistry

    def initialize(dao_registry_loader: nil, dao_registry: nil)
      set_dao_registry_and_loader dao_registry_loader, dao_registry
      @identity_map = {}
    end

    ##############################
    # DELEGATING TO DAO REGISTRY #
    ##############################

    delegate :exist?, :aggregations_factory, to: :dao_registry

    def respond_to_missing?(method_name, include_private = false)
      dao_registry.respond_to? method_name, include_private
    end

    def method_missing(method_name, *arguments, &block)
      dao_registry.send method_name, *arguments, &block
    end

    def get(key, override_dao_registry: nil)
      override_dao_registry ||= self
      dao_registry.get key, override_dao_registry: override_dao_registry
    end

    ###########################
    # IDENTITY MAP FOR MODELS #
    ###########################

    def register_model(model)
      model_dao_name, primary_key = keys_from_model(model, action: :register)
      return self unless model_dao_name.present? && primary_key.present?

      log "register model #{model_dao_name}:#{primary_key}"

      @identity_map[model_dao_name] ||= {}
      @identity_map[model_dao_name][primary_key] = model

      self
    end

    def unload_model(model)
      model_dao_name, primary_key = keys_from_model(model, action: :unload)
      return self unless model_dao_name.present? && primary_key.present?

      log "unload model #{model_dao_name}:#{primary_key}"

      @identity_map[model_dao_name] ||= {}
      @identity_map[model_dao_name].delete primary_key

      self
    end

    def get_model(model_dao_name, primary_key)
      model_dao_name = model_dao_name.to_s
      primary_key = primary_key.to_s
      return nil unless model_dao_name.present? && primary_key.present?

      @identity_map[model_dao_name] ||= {}
      val = @identity_map[model_dao_name][primary_key]

      if val.nil?
        log "get model #{model_dao_name}:#{primary_key} NOT PRESENT"
      else
        log "get model #{model_dao_name}:#{primary_key} PRESENT!!!!!"
      end

      val
    end

    private
    def log(msg)
      ArtirixDataModels.logger.debug "DAO-REGISTRY-IDENTITY-MAP #{object_id} => #{msg}"
    end

    def keys_from_model(model, action: :use)
      model_dao_name = model.try :model_dao_name
      primary_key    = model.try :primary_key

      if model_dao_name.blank?
        ArtirixDataModels.logger.error("model does not have a `model_dao_name` #{model}: we cannot #{action} it")
      end

      if primary_key.blank?
        ArtirixDataModels.logger.error("model does not have a `primary_key` #{model}: we cannot #{action} it")
      end

      [model_dao_name.to_s, primary_key.to_s]
    end

  end
end