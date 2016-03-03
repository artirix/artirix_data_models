# :nocov:
shared_examples_for 'an ArtirixDataModel DAO' do
  # example of needed definitions
  #
  # # CONFIG for tests
  #
  # Given(:model_class) { Article }
  # Given(:partial_mode_key) { :article }
  # Given(:primary_key_attribute) { :slug }
  # Given(:partial_mode_attribute) { :name }
  # Given(:full_mode_attribute) { :snippet_text }
  # Given(:path_full) { "/articles/full/#{slug}" }
  # Given(:path_partial) { "/articles/partial/#{slug}" }
  #
  # # DATA for tests
  # Given(:slug) { 'my-slug' }
  # Given(:name) { 'my name' }
  # Given(:snippet_text) { 'my snippet_text' }


  # COMMON MODEL SPEC
  Given(:primary_key) { send(primary_key_attribute) }
  Given(:primary_key_attribute_value) { primary_key }
  Given(:partial_mode_attribute_value) { send(partial_mode_attribute) }
  Given(:full_mode_attribute_value) { send(full_mode_attribute) }

  Given(:_timestamp) { rand(1..300).minutes.ago.to_s }

  Given(:data_hash_partial) do
    {
      :_timestamp            => _timestamp,
      primary_key_attribute  => primary_key_attribute_value,
      partial_mode_attribute => partial_mode_attribute_value
    }
  end
  Given(:data_hash_full) do
    data_hash_partial.merge full_mode_attribute => full_mode_attribute_value
  end

  Given(:json_partial) { data_hash_partial.to_json }
  Given(:json_full) { data_hash_full.to_json }

  # mock gateway calls
  Given(:gateway) do
    ArtirixDataModels::DataGateway.new.tap do |gateway|
      expect(gateway).to receive(:perform).with(:get, path: path_full, body: nil, json_body: true, timeout: nil).and_return(json_full).at_most(:once)
      expect(gateway).to receive(:perform).with(:get, path: path_partial, body: nil, json_body: true, timeout: nil).and_return(json_partial).at_most(:once)
    end
  end

  Given(:subject) { described_class.new gateway: gateway }

  # 1. get partial model by primary key
  describe '#get' do
    When(:result) { subject.get primary_key }
    Then { result.is_a? model_class }
    Then { result.primary_key == primary_key }
    Then { result.send(partial_mode_attribute) == partial_mode_attribute_value }
    Then { result.partial_mode? == true }
  end

  # 2. get full model by primary key
  describe '#get_full' do
    When(:result) { subject.get_full(primary_key) }
    Then { result.is_a? model_class }
    Then { result.primary_key == primary_key }
    Then { result.send(partial_mode_attribute) == partial_mode_attribute_value }
    Then { result.full_mode? == true }
  end

  # 3. reload a model in partial mode with full info
  describe '#reload' do
    Given(:model) { subject.get primary_key }
    When(:result) { subject.reload(model) }
    Then { result == model }
    Then { model.is_a? model_class }
    Then { model.primary_key == primary_key }
    Then { model.send(partial_mode_attribute) == partial_mode_attribute_value }
    Then { model.send(full_mode_attribute) == full_mode_attribute_value }
    Then { model.full_mode? == true }
  end

  # 4. partial mode field list
  describe '#partial_mode_fields' do
    Given(:partial_mode_fields_list) { [:_timestamp, primary_key_attribute, partial_mode_attribute] }
    Given(:model_fields_dao) do
      ArtirixDataModels::ModelFieldsDAO.new.tap { |m| allow(m).to receive(:partial_mode_fields_for).with(partial_mode_key).and_return(partial_mode_fields_list) }
    end

    Given do
      allow(ArtirixDataModels::DAORegistry).to receive(:model_fields).and_return(model_fields_dao)
    end

    When(:result) { subject.partial_mode_fields }
    Then { result == partial_mode_fields_list }
  end
end
# :nocov: