require 'spec_helper'

RSpec.describe ArtirixDataModels::ADMRegistry, type: :model do
  Given(:subject) { described_class.instance }

  # common config mock
  given_gateway_config


  describe '#gateway' do
    When(:gateway) { subject.gateway }
    Then { gateway.is_a? ArtirixDataModels::DataGateway }
  end

  describe '#model_fields' do
    When(:model_fields) { subject.model_fields }
    Then { model_fields.is_a? ArtirixDataModels::ModelFieldsDAO }
    Then { model_fields.gateway == subject.gateway }
  end

end