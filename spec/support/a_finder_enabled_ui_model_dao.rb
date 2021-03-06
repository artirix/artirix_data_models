shared_examples_for 'a finder enabled UI ModelDAO' do

  # COMMON MODEL SPEC
  Given(:primary_key) { send(primary_key_attribute) }
  Given(:primary_key_attribute_value) { primary_key }
  Given(:partial_mode_attribute_value) { send(partial_mode_attribute) }

  Given(:data_hash_partial) do
    {
        primary_key_attribute  => primary_key_attribute_value,
        partial_mode_attribute => partial_mode_attribute_value
    }
  end

  Given(:json_find_by) do
    data_hash_partial.to_json
  end

  # mock gateway calls
  Given(:gateway) do
    ArtirixDataModels::DataGateway.new.tap do |gateway|
      expected_params = {
        path:                     path_for_find_by,
        body:                     nil,
        json_body:                true,
        timeout:                  nil,
        authorization_bearer:     nil,
        authorization_token_hash: nil,
        headers:                  nil
      }
      expect(gateway).to receive(:perform).with(:get, expected_params).and_return(json_find_by).at_most(:once)
    end
  end

  Given(:subject) { described_class.new gateway: gateway }

  # get a single model object by given parameters
  describe '#find_by' do
    When(:result) { subject.find_by params_for_find_by }
    Then { result.is_a? model_class }
    Then { result.primary_key == primary_key }
    Then { result.send(partial_mode_attribute) == partial_mode_attribute_value }
    Then { result.partial_mode? == true }
  end
end
