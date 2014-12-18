# based on https://github.com/geoffharcourt/active_model_lint-rspec/blob/master/lib/active_model_lint-rspec/an_active_model.rb
shared_examples_for 'a ReadOnly ActiveModel like ArtirixDataModels' do
  require 'active_model/lint'
  include ActiveModel::Lint::Tests

  before do
    @model = subject
  end

  ActiveModel::Lint::Tests.public_instance_methods.map { |method| method.to_s }.grep(/^test/).each do |method|
    example(method.gsub('_', ' ')) { send method }
  end

  context 'cannot be saved' do
    it do
      expect { subject.save }.to raise_error ArtirixDataModels::Model::Errors::ReadOnlyModelError
    end
  end
end

