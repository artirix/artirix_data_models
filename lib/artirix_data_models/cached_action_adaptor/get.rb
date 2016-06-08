class ArtirixDataModels::CachedActionAdaptor::Get < ArtirixDataModels::CachedActionAdaptor

  attr_reader :dao_name, :model_pk

  def initialize(dao_name:, model_pk:, **extra_options)
    @dao_name = dao_name
    @model_pk = model_pk

    super(**extra_options)
  end

  def load_cache_key
    ArtirixDataModels::CacheService.key :dao_get, dao_name, model_pk
  end

  def load_cache_options
    ArtirixDataModels::CacheService.first_options "dao_#{dao_name}_get_options",
                                                  "dao_#{dao_name}_options",
                                                  'dao_get_options',
                                                  return_if_missing: :default
  end
end
