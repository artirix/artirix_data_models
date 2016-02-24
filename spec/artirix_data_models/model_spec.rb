require 'spec_helper'

class MyModel
  include ArtirixDataModels::Model::OnlyData

  attribute :id, :name

  attribute :public_title, writer_visibility: :public
  attribute :private_title, reader_visibility: :private

  attribute :remember_me, :and_me, skip: :predicate
  attribute :remember_me2, :and_me2, skip: :presence

end

RSpec.describe MyModel, type: :model do

  subject { described_class.new data }

  let(:data) do
    {
      name:         name,
      remember_me:  remember_me,
      and_me:       and_me,
      remember_me2: remember_me2,
      and_me2:      and_me2,
    }
  end

  let(:name) { 'Paco' }
  let(:remember_me) { 'yeah' }
  let(:and_me) { 'and' }
  let(:remember_me2) { 'other' }
  let(:and_me2) { 'stuff' }

  describe '.attribute' do
    it 'creates public getter' do
      expect(subject).to respond_to :id
      expect(subject).to respond_to :name
    end

    it 'loads info from hash passed in object creation' do
      expect(subject.id).to be_nil
      expect(subject.name).to eq name
    end

    it 'creates private setter' do
      expect(subject.respond_to? :name=).to be_falsey
      expect(subject.respond_to? :name=, true).to be_truthy

      expect(subject.name).to eq name
      subject.send :name=, 123
      expect(subject.name).to eq 123
    end

    it 'creates predicate method' do
      expect(subject).to respond_to :id?
      expect(subject).to respond_to :name?

      expect(subject.id?).to be_falsey
      expect(subject.name?).to be_truthy
    end

    it 'creates private setter' do
      expect(subject.respond_to? :name=).to be_falsey
      expect(subject.respond_to? :name=, true).to be_truthy

      expect(subject.name).to eq name
      subject.send :name=, 123
      expect(subject.name).to eq 123
    end

    context 'with option `writer_visibility: :public`' do
      it 'writer is public' do
        expect(subject.respond_to? :public_title=).to be_truthy
        expect(subject.respond_to? :public_title=, true).to be_truthy

        expect(subject.public_title).to be_nil
        subject.public_title = 411
        expect(subject.public_title).to eq 411
      end
    end

    context 'with option `reader_visibility: :private`' do
      it 'reader is private' do
        expect(subject.respond_to? :private_title).to be_falsey
        expect(subject.respond_to? :private_title, true).to be_truthy

        expect(subject.send :private_title).to be_nil
        subject.send :private_title=, 411
        expect(subject.send :private_title).to eq 411
      end
    end

    context 'with option `skip: :predicate` or `skip: :presence`' do

      it 'does not create predicate method' do
        expect(subject).to respond_to :remember_me
        expect(subject).to respond_to :and_me
        expect(subject).to respond_to :remember_me2
        expect(subject).to respond_to :and_me2

        #not public
        expect(subject.respond_to? :remember_me?).to be_falsey
        expect(subject.respond_to? :and_me?).to be_falsey
        expect(subject.respond_to? :remember_me2?).to be_falsey
        expect(subject.respond_to? :and_me2?).to be_falsey

        #not private either
        expect(subject.respond_to? :remember_me?, true).to be_falsey
        expect(subject.respond_to? :and_me?, true).to be_falsey
        expect(subject.respond_to? :remember_me2?, true).to be_falsey
        expect(subject.respond_to? :and_me2?, true).to be_falsey

        expect(subject.remember_me).to eq remember_me
        expect(subject.and_me).to eq and_me
        expect(subject.remember_me2).to eq remember_me2
        expect(subject.and_me2).to eq and_me2
      end

    end
  end

end