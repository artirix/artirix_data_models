# :nocov:
def fake_mode_for(model_name)
  before(:all) do
    SimpleConfig.for(:site) do

      set :debug_model_mode_enabled, true

      group :data_fake_mode do
        set model_name, true
      end
    end
  end

  after(:all) do
    SimpleConfig.for(:site) do

      set :debug_model_mode_enabled, false

      group :data_fake_mode do
        set model_name, false
      end
    end
  end
end

# :nocov: