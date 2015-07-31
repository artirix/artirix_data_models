require 'spec_helper'

RSpec.describe ArtirixDataModels::ModelFieldsDAO, type: :model do
  Given(:field_list) { ['a', 'b'] }
  Given(:parsed_response_field_list) { field_list }
  Given(:response_field_list) { Oj.dump parsed_response_field_list }

  Given(:model_name) { 'my_model' }
  Given(:path_fields) { "/partial_fields/#{model_name}" }

  Given(:model_unknown) { 'noooope' }
  Given(:path_fields_unknown) { "/partial_fields/#{model_unknown}" }


  Given(:gateway) do
    double('gateway').tap do |gateway|
      expect(gateway).to receive(:get).with(path_fields).and_return(parsed_response_field_list).at_most(:once)
      expect(gateway).to receive(:get).with(path_fields_unknown).at_most(:once) do
        raise ArtirixDataModels::DataGateway::NotFound
      end
    end
  end

  Given(:subject) { described_class.new gateway: gateway }

  describe '#partial_mode_fields_for' do
    When(:result) { subject.partial_mode_fields_for model_name }
    Then { result == field_list }

    context 'when asking several times => only looks for the info once' do
      When(:result) { 3.times.map { subject.partial_mode_fields_for model_name }.last }
      Then { result == field_list }
    end

    context 'when asking for an unknown one => empty list' do
      When(:result) { subject.partial_mode_fields_for model_unknown }
      Then { result == [] }
    end
  end
end