# :nocov:
def fake_mode_for(model_name)
  before(:each) do
    config = ArtirixDataModels.configuration

    # fix in case of SimpleConfig (mocking SimpleConfig with rspec explodes if not)
    if defined?(SimpleConfig) && config.kind_of?(SimpleConfig::Config)
      SimpleConfig::Config.class_eval { public :singleton_class }
    end

    dfm = config.try(:data_fake_mode) || double
    allow(dfm).to receive(model_name).and_return(true)
    allow(config).to receive(:data_fake_mode).and_return(dfm)

    allow(config).to receive(:debug_model_mode_enabled).and_return(true)
  end
end

# :nocov: