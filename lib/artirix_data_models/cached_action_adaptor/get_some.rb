class ArtirixDataModels::CachedActionAdaptor::GetSome < ArtirixDataModels::CachedActionAdaptor

  attr_reader :dao_name, :model_pks

  def initialize(dao_name:, model_pks:, **extra_options)
    @dao_name  = dao_name
    @model_pks = Array(model_pks)

    super(**extra_options)
  end

  def load_cache_key
    ArtirixDataModels::CacheService.dao_get_key(dao_name, model_pks)
  end

  def load_cache_options
    ArtirixDataModels::CacheService.first_options "dao_#{dao_name}_get_some_options",
                                                  "dao_#{dao_name}_options",
                                                  'dao_get_some_options',
                                                  return_if_none: :default
  end
end
