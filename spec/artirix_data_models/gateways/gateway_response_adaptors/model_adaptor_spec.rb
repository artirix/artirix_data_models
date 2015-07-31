require 'spec_helper'

RSpec.describe ArtirixDataModels::GatewayResponseAdaptors::ModelAdaptor, type: :model do
  before do
    settings = OpenStruct.new(search_page_size: OpenStruct.new(default: 15))
    allow(SimpleConfig).to receive(:for).and_return(settings).twice
  end

  describe '.new' do
    context 'with callable object' do
      Given(:callable) do
        ->(data_hash) { { given: data_hash } }
      end
      Given(:example_data_hash) { { some: :stuff } }

      When(:subject) { described_class.with_callable callable }
      Then { subject.object_creator == callable }
      And { subject.object_creator.call(example_data_hash) == { given: example_data_hash } }
    end

    context 'with block' do
      Given(:example_data_hash) { { some: :stuff } }

      When(:subject) do
        described_class.with_block do |data_hash|
          { given: data_hash }
        end
      end
      Then { subject.object_creator.respond_to? :call }
      And { subject.object_creator.call(example_data_hash) == { given: example_data_hash } }
    end

    context 'with model class' do
      context 'when single model object' do
        Given(:model_class) do
          Class.new do
            attr_reader :data

            def initialize(data)
              @data = { given: data }
            end
          end
        end

        Given(:example_data_hash) { { some: :stuff } }

        When(:subject) { described_class.single model_class }
        Then { subject.object_creator.call(example_data_hash).data == { given: example_data_hash } }
      end

      context 'when collection of model objects' do
        Given(:model_class) do
          Class.new do
            attr_reader :data

            def initialize(data)
              @data = { given: data }
            end
          end
        end

        Given(:example_data_hash) do
          {
            hits: {
              hits: [
                { _source: { some: :stuff       } },
                { _source: { some: :more_stuff  } },
              ]
            }
          }
        end

        When(:subject) { described_class.collection model_class }
        Then { subject.object_creator.call(example_data_hash).each_with_index {|instance, index| instance.data == { given: example_data_hash } } }
      end
    end
  end
end
