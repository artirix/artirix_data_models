require 'spec_helper'

class InspectModel
  include ArtirixDataModels::Model::OnlyData

  attribute :id, :list, :name
end

RSpec.describe InspectModel, type: :model do

  subject { described_class.new data }

  let(:data) do
    {
      name: name,
      list: list
    }
  end

  let(:list) do
    [
      described_class.new(list: nil, name: 'nested element of list 1'),
      described_class.new(list: nil, name: 'nested element of list 2'),
    ]
  end

  let(:name) { 'Paco' }

  describe '#inspect' do
    let(:expected) do
<<-STR.strip
#<InspectModel
     - id: nil
     - list: [
         - #<InspectModel
             - id: nil
             - list: nil
             - name: "nested element of list 1">
         - #<InspectModel
             - id: nil
             - list: nil
             - name: "nested element of list 2">
       ]
     - name: "Paco">
STR
    end
    it do
      expect(subject.inspect).to eq expected
    end
  end
end