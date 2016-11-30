class ArtirixDataModels::ADMRegistry
  @instance_mutex = Mutex.new

  def self.instance_mutex
    ArtirixDataModels::ADMRegistry.instance_variable_get :@instance_mutex
  end

  def self.instance
    instance_mutex.synchronize {
      @instance = new unless @instance
      @instance
    }
  end

  def self.instance=(x)
    instance_mutex.synchronize {
      @instance = x
      @instance
    }
  end

  def self.mark_as_main_registry
    ArtirixDataModels::ADMRegistry.instance = self.instance
  end

  # singleton instance
  def initialize
    @persistent_mutex = Mutex.new
    @transient_mutex = Mutex.new

    @repository = {}
    @persistent_loaders = {}
    @transient_loaders = {}

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
    repository_has_key?(key) || has_persistent_loader?(key) || has_transient_loader?(key)
  end

  def get(key, override_adm_registry: nil)
    x = @repository[key.to_sym] || call_loader(key)
    if x.present? && override_adm_registry.present? && x.respond_to?(:set_adm_registry)
      x.set_adm_registry override_adm_registry
    end

    x
  end

  def set_transient_loader(key, loader = nil, &block)
    key = key.to_sym

    if block
      value_to_store = block
    elsif loader.respond_to? :call
      value_to_store = loader
    else
      raise ArgumentError, "no block and no loader given for key #{key}"
    end

    @transient_mutex.synchronize { @transient_loaders[key] = value_to_store }
  end

  def set_persistent_loader(key, loader = nil, &block)
    key = key.to_sym

    if block
      value_to_store = block
    elsif loader.respond_to? :call
      value_to_store = loader
    else
      raise ArgumentError, "no block and no loader given for key #{key}"
    end

    @persistent_mutex.synchronize { @persistent_loaders[key] = value_to_store }
  end

  alias_method :set_loader, :set_persistent_loader

  ################
  # IDENTITY MAP #
  ################

  def with_identity_map
    IdentityMap.new adm_registry: self
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
    if @persistent_loaders[key]
      @persistent_loaders[key].call.tap do |value_to_store|
        @persistent_mutex.synchronize { @repository[key] = value_to_store }
      end
    elsif @transient_loaders[key]
      @transient_loaders[key].call
    else
      raise LoaderNotFound, "no loader or transient found for #{key}"
    end
  end

  def has_transient_loader?(key)
    @transient_loaders.key?(key)
  end

  def has_persistent_loader?(key)
    @persistent_loaders.key?(key)
  end

  def repository_has_key?(key)
    @repository.key?(key)
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
    include ArtirixDataModels::WithADMRegistry

    def initialize(adm_registry_loader: nil, adm_registry: nil)
      set_adm_registry_and_loader adm_registry_loader, adm_registry
      @identity_map = {}
    end

    ##############################
    # DELEGATING TO DAO REGISTRY #
    ##############################

    delegate :exist?, :aggregations_factory, to: :adm_registry

    def respond_to_missing?(method_name, include_private = false)
      adm_registry.respond_to? method_name, include_private
    end

    def method_missing(method_name, *arguments, &block)
      adm_registry.send method_name, *arguments, &block
    end

    def get(key, override_adm_registry: nil)
      override_adm_registry ||= self
      adm_registry.get key, override_adm_registry: override_adm_registry
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
      primary_key = model.try :primary_key

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