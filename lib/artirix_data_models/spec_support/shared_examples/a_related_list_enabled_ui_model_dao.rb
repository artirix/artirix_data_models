shared_examples_for 'a related list enabled UI ModelDAO' do

  # COMMON MODEL SPEC
  Given(:primary_key) { send(primary_key_attribute) } # TODO: remove
  Given(:primary_key_attribute_value) { related_item[primary_key_attribute] }
  Given(:partial_mode_attribute_value) { related_item[partial_mode_attribute] }
  Given(:full_mode_attribute_value) { related_item[full_mode_attribute] }

  Given(:data_hash_partial) do
    {
        primary_key_attribute  => primary_key_attribute_value,
        partial_mode_attribute => partial_mode_attribute_value
    }
  end
  Given(:data_hash_full) do
    data_hash_partial.merge full_mode_attribute => full_mode_attribute_value
  end

  Given(:json_full) { data_hash_full.to_json }
  Given(:json_related) do
    { hits: { hits: [ _source: data_hash_full ] } }.to_json
  end

  # mock gateway calls
  Given(:gateway) do
    ArtirixDataModels::DataGateway.new.tap do |gateway|
      expect(gateway).to receive(:perform_get).with(path_for_related, nil).and_return(json_related).at_most(:once)
    end
  end

  Given(:subject) { described_class.new gateway: gateway }

  # get list of results by search term
  describe '#search' do
    When(:result) { subject.related(params_for_related.merge({ model_pk: primary_key })) }
    Then { result.is_a? ArtirixDataModels::EsCollection }
    Then { result.first.is_a? model_class }
    # should not return itself
    Then { !result.any? { |x| x.primary_key == primary_key } }
  end
end
