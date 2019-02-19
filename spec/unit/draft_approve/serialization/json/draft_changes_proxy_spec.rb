require 'spec_helper'

RSpec.describe DraftApprove::Serialization::Json::DraftChangesProxy do
  let(:const_type) { DraftApprove::Serialization::Json::Helper::TYPE }
  let(:const_id)   { DraftApprove::Serialization::Json::Helper::ID }

  let(:serialization) { DraftApprove::Serialization::Json }
  let(:proxy)         { serialization::DraftChangesProxy }
  let(:transaction)   { FactoryBot.create(:draft_transaction,serialization: serialization.name) }

  context 'when proxying a Draft object' do
    let(:draft) do
      FactoryBot.create(
        :draft,
        draft_transaction: transaction,
        draftable_type: model.class.name,
        draftable_id: model.id,
        draft_changes: changes
      )
    end

    let(:subject) { proxy.new(draft) }

    context 'when model is a new record' do
      let(:name)    { 'Fake Name' }
      let(:gender)  { FactoryBot.create(:gender) }
      let(:model)   { FactoryBot.build(:person, name: name, gender: gender) }
      let(:changes) do
        {
          "name" => [nil,name],
          "gender" => [
            nil,
            { const_type => gender.class.name, const_id => gender.id }
          ]
        }
      end

      describe '#changed?' do
        it 'returns true' do
          expect(subject.changed?).to be(true)
        end
      end

      describe '#changed' do
        let(:expected_result) { changes.keys }
        it 'returns the changed attributes' do
          expect(subject.changed).to eq(expected_result)
        end
      end

      describe '#changes' do
        let(:expected_result) do
          {
            "name" => [nil, name],
            "gender" => [nil, proxy.new(gender, transaction)]
          }
        end

        it 'returns the changes hash' do
          expect(subject.changes).to eq(expected_result)
        end
      end

      describe '#old_value' do
        it 'returns nil for simple attribute' do
          expect(subject.old_value('name')).to be(nil)
        end

        it 'returns nil for belongs_to association' do
          expect(subject.old_value('gender')).to be(nil)
        end

        it 'returns empty array for has_many association' do
          expect(subject.old_value('memberships')).to eq([])
        end

        it 'returns empty array for polymorphic has_many association' do
          expect(subject.old_value('contact_addresses')).to eq([])
        end
      end

      describe '#new_value' do
        it 'returns value from the draft for simple attribute' do
          expect(subject.new_value('name')).to eq(name)
        end

        it 'returns value from the draft for belongs_to association' do
          expect(subject.new_value('gender')).to eq(proxy.new(gender, transaction))
        end

        it 'returns value from draftable for has_many association' do
          expect(subject.new_value('memberships')).to eq([])
        end

        it 'returns value from draftable for polymorphic has_many association' do
          expect(subject.new_value('contact_addresses')).to eq([])
        end
      end
    end

    context 'when changes is empty' do
      let(:name)    { 'Fake Name' }
      let(:model)   { FactoryBot.create(:person, name: name, gender: nil) }
      let(:changes) { {} }

      describe '#changed?' do
        it 'returns false' do
          expect(subject.changed?).to be(false)
        end
      end

      describe '#changed' do
        it 'returns empty array' do
          expect(subject.changed).to eq([])
        end
      end

      describe '#changes' do
        it 'returns empty hash' do
          expect(subject.changes).to eq({})
        end
      end

      describe '#old_value' do
        it 'returns value from the draftable for simple attribute' do
          expect(subject.old_value('name')).to eq(name)
        end

        it 'returns value from the draftable for belongs_to association' do
          expect(subject.old_value('gender')).to eq(nil)
        end

        it 'returns value from the draftable for has_many association' do
          expect(subject.old_value('memberships')).to eq([])
        end

        it 'returns value from the draftable for polymorphic has_many association' do
          expect(subject.old_value('contact_addresses')).to eq([])
        end
      end

      describe '#new_value' do
        it 'returns value from the draftable for simple attribute' do
          expect(subject.new_value('name')).to eq(name)
        end

        it 'returns value from the draftable for belongs_to association' do
          expect(subject.new_value('gender')).to eq(nil)
        end

        it 'returns value from the draftable for has_many association' do
          expect(subject.new_value('memberships')).to eq([])
        end

        it 'returns value from the draftable for polymorphic has_many association' do
          expect(subject.new_value('contact_addresses')).to eq([])
        end
      end
    end
  end

  context 'when proxying a draftable object' do

  end
end
