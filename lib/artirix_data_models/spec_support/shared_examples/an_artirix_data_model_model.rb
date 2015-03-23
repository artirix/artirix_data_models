
shared_examples_for 'an ArtirixDataModel Model' do

  # Example of Config:
  # =================
  # Given(:dao_class) { ArticleDAO }
  # Given(:cache_key_prefix) { 'article' }
  #
  # Given(:primary_key_attribute) { :slug }
  # Given(:partial_mode_attribute) { :name }
  # Given(:full_mode_attribute) { :snippet_text }
  # Given(:path_full) { "/articles/full/#{slug}" }
  # Given(:path_partial) { "/articles/partial/#{slug}" }
  # Given(:path_partial_fields) { '/partial_fields/article' }
  #
  # # DATA for tests
  # Given(:slug) { 'my-slug' }
  # Given(:name) { 'my name' }
  # Given(:snippet_text) { 'my snippet_text' }
  #
  # Given(:partial_mode_list) do
  #   [:_timestamp, :slug, :name]
  # end
  #
  # Given(:automatic_attributes) do
  #   [:_timestamp]
  # end
  #
  # Given(:defined_attributes) do
  #   [
  #       :noindex,
  #   ]
  # end

  Given(:primary_key) { send(primary_key_attribute) }
  Given(:primary_key_attribute_value) { primary_key }
  Given(:partial_mode_attribute_value) { send(partial_mode_attribute) }
  Given(:full_mode_attribute_value) { send(full_mode_attribute) }


  # 1. ActiveModel compliant (to_param, valid?, save...)
  it_behaves_like 'a ReadOnly ActiveModel like ArtirixDataModels'

  # 2. Attributes (on initialise, getters and private setters)
  context 'attributes' do
    Given(:attributes) { defined_attributes }
    it_behaves_like 'has attributes'

    describe 'parameters given on initialise' do
      Given(:attribute) { partial_mode_attribute }
      Given(:value) { 1 }
      When(:subject) { described_class.new attribute => value }
      Then { subject.send(attribute) == value }
    end

    describe 'parameters given on `_set_properties`' do
      Given(:attribute) { partial_mode_attribute }
      Given(:value) { 1 }
      Given(:subject) { described_class.new }
      When { subject.send(:_set_properties, attribute => value) }
      Then { subject.send(attribute) == value }
    end
  end

  # 3. Automatic timestamp attribute attributes definition (_timestamp)
  context 'automatic attributes' do
    Given(:attributes) { automatic_attributes }
    it_behaves_like 'has attributes'
  end

  # 4. Definition of Primary Key
  describe '#primary_key' do
    describe 'use slug as primary_key_attribute' do
      When(:subject) { described_class.new primary_key_attribute => primary_key }
      Then { subject.primary_key == primary_key }
    end
  end


  context 'using dao' do
    describe '.dao' do
      context 'no dao given on object creation' do
        Given(:subject) { described_class.new }
        When(:dao) { subject.dao }
        Then { dao.kind_of? dao_class }
      end

      context 'dao given on object creation' do
        Given(:given_dao) { double('dao') }
        Given(:subject) { described_class.new dao: given_dao }
        When(:dao) { subject.dao }
        Then { dao == given_dao }
      end
    end

    # 5. Cache key (calculation of cache key based on minimum information)
    describe '#cache_key' do
      describe 'based on model_name, primary_key and timestamp' do
        Given(:timestamp) { Time.now.utc }
        When(:subject) { described_class.new primary_key_attribute => primary_key, _timestamp: timestamp.to_s }
        Then { subject.cache_key == "#{cache_key_prefix.to_s.parameterize}/#{primary_key.to_s.parameterize}/#{timestamp.to_s.parameterize}" }
      end
    end

    # 6. Partial mode (reload, automatic reload when accessing an unavailable attribute)
    # TODO: partial mode

    context 'partial mode' do
      Given(:value) { 'my value' }
      Given(:new_value) { 'my value changed' }
      Given(:old_data) { { primary_key_attribute => primary_key, partial_mode_attribute => value } }
      Given(:new_data) { { primary_key_attribute => primary_key, full_mode_attribute => full_mode_attribute_value, partial_mode_attribute => new_value } }

      # 6.1 partial mode - Reload with new data hash
      describe '#reload_with' do
        Given(:subject) { described_class.new old_data }

        When { subject.reload_with(new_data) }
        Then { subject.send(partial_mode_attribute) == new_value }
        Then { subject.send(full_mode_attribute) == full_mode_attribute_value }
      end

      # 6.2 partial mode - Check if in partial mode or in full mode
      describe '#partial_mode? (true by default) and #full_mode? (false by default)' do
        context 'new object' do
          When(:subject) { described_class.new }
          Then { subject.partial_mode? == true }
          Then { subject.full_mode? == false }
        end

        describe '#mark_partial_mode' do
          Given(:subject) { described_class.new }
          When { subject.mark_partial_mode }
          Then { subject.partial_mode? == true }
          Then { subject.full_mode? == false }
        end

        describe '#mark_full_mode' do
          Given(:subject) { described_class.new }
          When { subject.mark_full_mode }
          Then { subject.partial_mode? == false }
          Then { subject.full_mode? == true }
        end
      end

      context 'reload using dao' do
        Given(:mock_dao) do
          double('dao').tap do |dao|
            allow(dao).to receive(:reload) do |x|
              x.reload_with new_data
              x.mark_full_mode
              x
            end

            allow(dao).to receive(:partial_mode_fields).and_return(partial_mode_list)
          end
        end

        # 6.3 partial mode - reload using DAO
        describe '#reload_model!' do
          Given(:subject) { described_class.new primary_key_attribute => primary_key, dao: mock_dao }
          When(:reloaded_subject) { subject.reload_model! }
          Then { reloaded_subject.full_mode? == true }
          Then { reloaded_subject.send(full_mode_attribute) == full_mode_attribute_value }
        end

        # 6.4 partial mode - list of partial fields
        context 'treat nil values' do
          context 'on attribute in the partial list => return nil without reloading' do
            Given(:subject) { described_class.new primary_key_attribute => primary_key, dao: mock_dao }
            Given do
              subject.reload_with(partial_mode_attribute => nil)
              expect(subject).not_to receive(:reload_model!)
            end

            When(:subject_value) { subject.send(partial_mode_attribute) }
            Then { subject_value.nil? }
            Then { subject.full_mode? == false }
          end

          context 'on attribute not in the partial list => reload' do
            Given(:subject) { described_class.new primary_key_attribute => primary_key, dao: mock_dao }
            Given do
              subject.reload_with(full_mode_attribute => nil)
              expect(subject).to receive(:reload_model!).once().and_call_original
            end

            When(:subject_full_mode_attribute) { subject.send(full_mode_attribute) }
            Then { subject_full_mode_attribute == full_mode_attribute_value }
            Then { subject.full_mode? == true }
          end
        end
      end
    end
  end

  # 7. Rails Model Param
  context 'rails model param' do
    When(:subject) { described_class.new primary_key_attribute => primary_key }

    describe '#to_param' do
      Then { subject.to_param == primary_key.to_s }
    end

    describe '#to_key' do
      Then { subject.to_key == [primary_key] }
    end
  end

  # 8. Data Hash
  describe '#data_hash' do
    Given(:partial) { { _timestamp: 3.seconds.ago.to_s, partial_mode_attribute => partial_mode_attribute_value, primary_key_attribute => primary_key, full_mode_attribute => full_mode_attribute_value } }
    Given(:data) { { _timestamp: 3.seconds.ago.to_s, partial_mode_attribute => partial_mode_attribute_value, primary_key_attribute => primary_key, full_mode_attribute => full_mode_attribute_value } }
    Given(:subject) { described_class.new data }

    Given do
      mock_gateway_get_response response: data.to_json, path: path_full
      mock_gateway_get_response response: partial_mode_list.to_json, path: path_partial_fields
    end


    When(:result) { subject.data_hash }
    Then { result.reject { |x, v| v.nil? } == data }
  end
end

