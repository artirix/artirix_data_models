shared_examples_for 'a search enabled UI ModelDAO' do

  # COMMON MODEL SPEC
  Given(:primary_key) { send(primary_key_attribute) }
  Given(:primary_key_attribute_value) { primary_key }
  Given(:partial_mode_attribute_value) { send(partial_mode_attribute) }
  Given(:full_mode_attribute_value) { send(full_mode_attribute) }

  Given(:data_hash_partial) do
    {
        primary_key_attribute  => primary_key_attribute_value,
        partial_mode_attribute => partial_mode_attribute_value
    }
  end
  Given(:data_hash_full) do
    data_hash_partial.merge full_mode_attribute => full_mode_attribute_value
  end

  Given(:json_search) do
    { hits: { hits: [ _source: data_hash_full ] } }.to_json
  end

  # mock gateway calls
  Given(:gateway) do
    ArtirixDataModels::DataGateway.new.tap do |gateway|
      expect(gateway).to receive(:perform_get).with(path_for_search, nil).and_return(json_search).at_most(:once)
    end
  end

  Given(:subject) { described_class.new gateway: gateway }

  # get list of results by search term
  describe '#search' do
    When(:result) { subject.search params_for_search }
    Then { result.is_a? ArtirixDataModels::EsCollection }
    Then { result.first.is_a? model_class }
    Then { result.first.primary_key == primary_key }
    Then { result.first.send(partial_mode_attribute) == data_hash_partial[partial_mode_attribute] }
  end
end
