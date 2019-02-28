require 'spec_helper'

RSpec.describe DraftApprove::Serialization::Json::DraftChangesProxy do
  let(:const_type) { DraftApprove::Serialization::Json::Constants::TYPE }
  let(:const_id)   { DraftApprove::Serialization::Json::Constants::ID }

  let(:serialization) { DraftApprove::Serialization::Json }
  let(:proxy)         { serialization::DraftChangesProxy }
  let(:transaction)   { FactoryBot.create(:draft_transaction,serialization: serialization.name) }

  describe '.new' do
    context 'when the given object is a Draft' do
      context 'when the Draft has no draftable object' do
        let(:model) { FactoryBot.build(:person) }
        let(:draft) do
          FactoryBot.create(
            :draft,
            draft_transaction: transaction,
            draftable_type: model.class.name,
            draftable_id: nil
          )
        end

        it 'has all attributes set correctly' do
          subject = proxy.new(draft)

          expect(subject.draft).to eq(draft)
          expect(subject.draftable).to be(nil)
          expect(subject.draftable_class).to eq(model.class)
          expect(subject.draft_transaction).to eq(transaction)
        end
      end

      context 'when the Draft has a persisted draftable object' do
        let(:draft) { FactoryBot.create(:draft, draft_transaction: transaction) }

        it 'has all attributes set correctly' do
          subject = proxy.new(draft)

          expect(subject.draft).to eq(draft)
          expect(subject.draftable).to eq(draft.draftable)
          expect(subject.draftable_class).to eq(draft.draftable.class)
          expect(subject.draft_transaction).to eq(transaction)
        end
      end

      context 'when the Draft has not been persisted' do
        let(:draft) { FactoryBot.build(:draft, draft_transaction: transaction) }

        it 'raises an ArgumentError' do
          expect do
            proxy.new(draft)
          end.to raise_error(ArgumentError)
        end
      end

      context 'when an explicit transaction is given' do
        let(:draft) { FactoryBot.create(:draft, draft_transaction: transaction) }

        context 'when the given transaction matches the Drafts transaction' do
          it 'has all attributes set correctly' do
            subject = proxy.new(draft, transaction)

            expect(subject.draft).to eq(draft)
            expect(subject.draftable).to eq(draft.draftable)
            expect(subject.draftable_class).to eq(draft.draftable.class)
            expect(subject.draft_transaction).to eq(transaction)
          end
        end

        context 'when the given transaction does not match the Drafts transaction' do
          let(:other_transaction) { FactoryBot.create(:draft_transaction) }
          it 'raises an ArgumentError' do
            expect do
              proxy.new(draft, other_transaction)
            end.to raise_error(ArgumentError)
          end
        end
      end
    end

    context 'when the given object is a draftable' do
      context 'when the draftable has no Draft within the given transaction' do
        let(:draftable) { FactoryBot.create(:person) }

        it 'has all attributes set correctly' do
          subject = proxy.new(draftable, transaction)

          expect(subject.draft).to be(nil)
          expect(subject.draftable).to eq(draftable)
          expect(subject.draftable_class).to eq(draftable.class)
          expect(subject.draft_transaction).to eq(transaction)
        end
      end

      context 'when the draftable has a Draft within the given transaction' do
        let(:draft) { FactoryBot.create(:draft, draft_transaction: transaction) }

        it 'has all attributes set correctly' do
          subject = proxy.new(draft.draftable, transaction)

          expect(subject.draft).to eq(draft)
          expect(subject.draftable).to eq(draft.draftable)
          expect(subject.draftable_class).to eq(draft.draftable.class)
          expect(subject.draft_transaction).to eq(transaction)
        end
      end

      context 'when the draftable has not been persisted' do
        let(:draftable) { FactoryBot.build(:person) }
        it 'raises an ArgumentError' do
          expect do
            proxy.new(draftable, transaction)
          end.to raise_error(ArgumentError)
        end
      end

      context 'when no transaction is given' do
        let(:draftable) { FactoryBot.create(:person) }
        it 'raises an ArgumentError' do
          expect do
            proxy.new(draftable)
          end.to raise_error(ArgumentError)
        end
      end
    end
  end

  context 'draft type methods' do
    context 'when proxying a Draft object' do
      let(:draft) do
        FactoryBot.create(
          :draft,
          draft_transaction: transaction,
          draft_action_type: draft_action_type
        )
      end
      let(:subject) { proxy.new(draft) }

      context 'when the Draft is a create' do
        let(:draft_action_type) { Draft::CREATE }
        it '#create? returns true' do
          expect(subject.create?).to be(true)
        end

        it '#delete? returns false' do
          expect(subject.delete?).to be(false)
        end
      end

      context 'when the Draft is an update' do
        let(:draft_action_type) { Draft::UPDATE }
        it 'create? returns false' do
          expect(subject.create?).to be(false)
        end

        it '#delete? returns false' do
          expect(subject.delete?).to be(false)
        end
      end

      context 'when the Draft is a delete' do
        let(:draft_action_type) { Draft::DELETE }
        it '#create? returns false' do
          expect(subject.create?).to be(false)
        end

        it '#delete? returns true' do
          expect(subject.delete?).to be(true)
        end
      end
    end

    context 'when proxying a draftable object with no Draft' do
      let(:draftable) { FactoryBot.create(:person) }
      let(:subject)   { proxy.new(draftable, transaction) }

      it '#create? returns false' do
        expect(subject.create?).to be(false)
      end

      it '#delete? returns false' do
        expect(subject.delete?).to be(false)
      end
    end

    context 'when proxying a draftable object with a Draft' do
      let(:draft) do
        FactoryBot.create(
          :draft,
          draft_transaction: transaction,
          draft_action_type: draft_action_type
        )
      end
      let(:subject) { proxy.new(draft.draftable, transaction) }

      context 'when the Draft is a create' do
        let(:draft_action_type) { Draft::CREATE }
        it '#create? returns true' do
          expect(subject.create?).to be(true)
        end

        it '#delete? returns false' do
          expect(subject.delete?).to be(false)
        end
      end

      context 'when the Draft is an update' do
        let(:draft_action_type) { Draft::UPDATE }
        it '#create? returns false' do
          expect(subject.create?).to be(false)
        end

        it '#delete? returns false' do
          expect(subject.delete?).to be(false)
        end
      end

      context 'when the Draft is a delete' do
        let(:draft_action_type) { Draft::DELETE }
        it '#create? returns false' do
          expect(subject.create?).to be(false)
        end

        it '#delete? returns true' do
          expect(subject.delete?).to be(true)
        end
      end
    end
  end

  context 'change methods' do
    let(:old_name) { 'Old Name' }
    let(:new_name) { 'New Name' }
    let(:gender)   { FactoryBot.create(:gender) }
    let(:model)    { FactoryBot.create(:person, name: old_name, gender: nil) }

    context 'when proxying a Draft object' do
      let(:draft) do
        FactoryBot.create(
          :draft,
          draft_transaction: transaction,
          draftable: model,
          draft_changes: changes
        )
      end
      let(:subject) { proxy.new(draft) }

      context 'when the Draft has no changes' do
        let(:changes) { {} }

        it '#changed? returns false' do
          expect(subject.changed?).to be(false)
        end

        it '#changed returns an empty array' do
          expect(subject.changed).to eq([])
        end

        it '#changes returns an empty hash' do
          expect(subject.changes).to eq({})
        end
      end

      context 'when the Draft has changes' do
        let(:changes) do
          {
            "name" => [old_name, new_name],
            "gender" => [nil, { const_type => gender.class.name, const_id => gender.id }]
          }
        end

        let(:expected_changes) do
          {
            "name" => [old_name, new_name],
            "gender" => [nil, proxy.new(gender, transaction)]
          }
        end

        it '#changed? returns true' do
          expect(subject.changed?).to be(true)
        end

        it '#changed returns the expected changed attribute names' do
          expect(subject.changed).to eq(expected_changes.keys)
        end

        it '#changes returns the hash of expected changes' do
          expect(subject.changes).to eq(expected_changes)
        end
      end
    end

    context 'when proxying a draftable object with no Draft' do
      let(:subject) { proxy.new(model, transaction) }

      it '#changed? returns false' do
        expect(subject.changed?).to be(false)
      end

      it '#changed returns an empty array' do
        expect(subject.changed).to eq([])
      end

      it '#changes returns an empty hash' do
        expect(subject.changes).to eq({})
      end
    end

    context 'when proxying a draftable object with a Draft' do
      let!(:draft) do
        FactoryBot.create(
          :draft,
          draft_transaction: transaction,
          draftable: model,
          draft_changes: changes
        )
      end
      let(:subject) { proxy.new(model, transaction) }

      context 'when the Draft has no changes' do
        let(:changes) { {} }

        it '#changed? returns false' do
          expect(subject.changed?).to be(false)
        end

        it '#changed returns an empty array' do
          expect(subject.changed).to eq([])
        end

        it '#changes returns an empty hash' do
          expect(subject.changes).to eq({})
        end
      end

      context 'when the Draft has changes' do
        let(:changes) do
          {
            "name" => [old_name, new_name],
            "gender" => [nil, { const_type => gender.class.name, const_id => gender.id }]
          }
        end

        let(:expected_changes) do
          {
            "name" => [old_name, new_name],
            "gender" => [nil, proxy.new(gender, transaction)]
          }
        end

        it '#changed? returns true' do
          expect(subject.changed?).to be(true)
        end

        it '#changed returns the expected changed attribute names' do
          expect(subject.changed).to eq(expected_changes.keys)
        end

        it '#changes returns the hash of expected changes' do
          expect(subject.changes).to eq(expected_changes)
        end
      end
    end
  end

  describe '#current_value' do
    context 'when there is no draftable' do
      let(:name)    { 'Person Name' }
      let(:gender)  { FactoryBot.create(:gender) }
      let(:person)  { FactoryBot.build(:person, name: name, gender: gender) }
      let(:contact) { FactoryBot.build(:contact_address, contactable: person) }
      let(:draft) do
        FactoryBot.create(
          :draft,
          draft_transaction: transaction,
          draftable_type: person.class.name,
          draftable_id: nil
        )
      end
      let(:subject) { proxy.new(draft) }

      it 'returns nil for a simple attribute' do
        expect(subject.current_value("name")).to be(nil)
      end

      it 'returns nil for a belongs_to association' do
        expect(subject.current_value("gender")).to be(nil)
      end

      it 'returns an empty array for a has_many association' do
        expect(subject.current_value("contact_addresses")).to eq([])
      end
    end

    context 'when there is a draftable' do
      let(:name)     { 'Person Name' }
      let(:gender)   { FactoryBot.create(:gender) }
      let(:person)   { FactoryBot.create(:person, name: name, gender: gender) }
      let(:contact1) { FactoryBot.create(:contact_address, contactable: person) }
      let(:contact2) { FactoryBot.create(:contact_address, contactable: person) }
      let(:draft) do
        FactoryBot.create(
          :draft,
          draft_transaction: transaction,
          draftable: person
        )
      end
      let(:subject) { proxy.new(draft) }

      it 'returns the current value for a simple attribute' do
        expect(subject.current_value("name")).to eq(name)
      end

      it 'returns a DraftChangesProxy of the current value for a belongs_to association' do
        expect(subject.current_value("gender")).to eq(proxy.new(gender, transaction))
      end

      it "returns an array of DraftChangesProxy's of the current values for has_many associations" do
        expected_values = [
          proxy.new(contact1, transaction),
          proxy.new(contact2, transaction)
        ]
        expect(subject.current_value("contact_addresses")).to match_array(expected_values)
      end
    end
  end

  describe '#new_value' do
    let!(:name)    { 'Person Name' }
    let!(:gender)  { FactoryBot.create(:gender) }
    let!(:person)  { FactoryBot.create(:person, name: name, gender: gender) }
    let!(:contact) { FactoryBot.create(:contact_address, contactable: person) }

    context 'when there is no Draft' do
      let(:subject) { proxy.new(person, transaction) }

      it 'returns the current value for a simple attribute' do
        expect(subject.new_value("name")).to eq(name)
      end

      it 'returns a DraftChangesProxy of the current value for a belongs_to association' do
        expect(subject.new_value("gender")).to eq(proxy.new(gender, transaction))
      end

      it "returns an array of DraftChangesProxy's of the current values for has_many associations" do
        expected_values = [proxy.new(contact, transaction)]
        expect(subject.new_value("contact_addresses")).to match_array(expected_values)
      end
    end

    context 'when there is a Draft' do
      let(:subject) { proxy.new(draft) }

      context 'simple attributes' do
        let(:draft) do
          FactoryBot.create(
            :draft,
            draft_transaction: transaction,
            draftable: person,
            draft_changes: changes
          )
        end

        context 'when there are no changes to the attribute' do
          let(:changes)  { {} }

          it 'returns the current value for a simple attribute' do
            expect(subject.new_value("name")).to eq(name)
          end
        end

        context 'when the new value is non-nil' do
          let(:new_name) { 'Person New Name' }
          let(:changes)  { { "name" => [name, new_name] } }

          it 'returns the new value for a simple attribute' do
            expect(subject.new_value("name")).to eq(new_name)
          end
        end

        context 'when the new value is nil' do
          let(:new_name) { nil }
          let(:changes)  { { "name" => [name, new_name] } }

          it 'returns the nil new value for a simple attribute' do
            expect(subject.new_value("name")).to be(nil)
          end
        end
      end

      context 'belongs_to associations' do
        let(:draft) do
          FactoryBot.create(
            :draft,
            draft_transaction: transaction,
            draftable: contact,
            draft_changes: changes
          )
        end

        context 'when there are no changes to the association' do
          let(:changes) { {} }
          it 'returns a DraftChangesProxy of the current value for a belongs_to association' do
            expect(subject.new_value("contactable")).to eq(proxy.new(person, transaction))
          end
        end

        context 'when the new value is an already persisted object' do
          let(:membership) { FactoryBot.create(:person) }
          let(:changes) do
            {
              "contactable" => [
                { const_type => person.class.name, const_id => person.id },
                { const_type => membership.class.name, const_id => membership.id }
              ]
            }
          end

          it 'returns a DraftChangesProxy of the new value for a belongs_to association' do
            expect(subject.new_value("contactable")).to eq(proxy.new(membership, transaction))
          end
        end

        context 'when the new value is a persisted draft in the same transaction' do
          let(:membership) do
            FactoryBot.build(
              :membership,
              :with_persisted_draft,
              draft_transaction: transaction
            )
          end

          let(:changes) do
            {
              "contactable" => [
                { const_type => person.class.name, const_id => person.id },
                { const_type => Draft.name, const_id => membership.draft_pending_approval.id }
              ]
            }
          end

          it 'returns a DraftChangesProxy of the new draft for a belongs_to association' do
            expect(subject.new_value("contactable")).to eq(proxy.new(membership.draft_pending_approval, transaction))
          end
        end

        context 'when the new value is a persisted draft in another transaction' do
          let(:membership) { FactoryBot.build(:membership, :with_persisted_draft) }

          let(:changes) do
            {
              "contactable" => [
                { const_type => person.class.name, const_id => person.id },
                { const_type => Draft.name, const_id => membership.draft_pending_approval.id }
              ]
            }
          end

          it 'raises an ArgumentError' do
            expect do
              subject.new_value("contactable")
            end.to raise_error(ArgumentError)
          end
        end

        context 'when the new value is nil' do
          let(:changes) do
            {
              "contactable" => [
                { const_type => person.class.name, const_id => person.id },
                nil
              ]
            }
          end

          it 'returns the nil new value for a belongs_to association' do
            expect(subject.new_value("contactable")).to be(nil)
          end
        end
      end
    end
  end

  context 'has_many associations' do
    let!(:name)    { 'Person Name' }
    let!(:gender)  { FactoryBot.create(:gender) }
    let!(:person)  { FactoryBot.create(:person, name: name, gender: gender) }
    let!(:contact) { FactoryBot.create(:contact_address, contactable: person) }

    context 'non-polymorphic has_many associations' do
      context 'when there is a draftable' do
        let(:subject)     { proxy.new(gender, transaction) }
        let(:association) { "people" }

        context 'when no additional drafts referencing the draftable have been created' do
          it "#new_value returns the DraftChangesProxy's for the current values" do
            expected_values = [proxy.new(person, transaction)]
            expect(subject.new_value(association)).to match_array(expected_values)
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when an additional draft referencing the draftable has been created' do
          let(:another_person) do
            FactoryBot.build(
              :person,
              :with_persisted_draft,
              draft_transaction: transaction,
              draft_action_type: Draft::CREATE,
              draft_changes: {
                "gender" => [
                  nil,
                  { const_type => Gender.name, const_id => gender.id }
                ]
              }
            )
          end

          it "#new_value returns an the DraftChangesProxy's for the current values and newly drafted values" do
            expected_values = [
              proxy.new(person, transaction),
              proxy.new(another_person.draft_pending_approval, transaction)
            ]
            expect(subject.new_value(association)).to match_array(expected_values)
          end

          it "#associations_added returns the DraftChangesProxy's for the newly drafted values" do
            expected_values = [
              proxy.new(another_person.draft_pending_approval, transaction)
            ]
            expect(subject.associations_added(association)).to match_array(expected_values)
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when a draft referencing the draftable has been created in another transaction' do
          let(:another_person) do
            FactoryBot.build(
              :person,
              :with_persisted_draft,
              draft_action_type: Draft::CREATE,
              draft_changes: {
                "gender" => [
                  nil,
                  { const_type => Gender.name, const_id => gender.id }
                ]
              }
            )
          end

          it "#new_value returns the DraftChangesProxy's for the current values" do
            expected_values = [proxy.new(person, transaction)]
            expect(subject.new_value(association)).to match_array(expected_values)
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when a draft removing the draftable reference from the existing association has been created' do
          let!(:person_draft) do
            FactoryBot.create(
              :draft,
              draft_transaction: transaction,
              draftable: person,
              draft_action_type: Draft::UPDATE,
              draft_changes: {
                "gender" => [
                  { const_type => Gender.name, const_id => gender.id },
                  nil
                ]
              }
            )
          end

          it "#new_value returns an empty array" do
            expect(subject.new_value(association)).to eql([])
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it "#associations_removed returns the DraftChangesProxy's for the draft" do
            expected_values = [proxy.new(person, transaction)]
            expect(subject.associations_removed(association)).to match_array(expected_values)
          end
        end

        context 'when a draft deleting the associated object has been created' do
          let!(:person_draft) do
            FactoryBot.create(
              :draft,
              draft_transaction: transaction,
              draftable: person,
              draft_action_type: Draft::DELETE,
              draft_changes: {}
            )
          end

          it "#new_value returns an empty array" do
            expect(subject.new_value(association)).to eql([])
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it "#associations_removed returns the DraftChangesProxy's for the draft" do
            expected_values = [proxy.new(person, transaction)]
            expect(subject.associations_removed(association)).to match_array(expected_values)
          end
        end
      end

      context 'when there is a Draft with no persisted draftable' do
        let(:new_gender) do
          FactoryBot.build(
            :gender,
            :with_persisted_draft,
            draft_transaction: transaction,
            draft_action_type: Draft::CREATE
          )
        end
        let(:subject)     { proxy.new(new_gender.draft_pending_approval) }
        let(:association) { "people" }

        context 'when no additional drafts referencing the subject draft have been created' do
          it '#new_value returns an empty array' do
            expect(subject.new_value(association)).to eql([])
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when an additional draft referencing the subject draft has been created' do
          let(:another_person) do
            FactoryBot.build(
              :person,
              :with_persisted_draft,
              draft_transaction: transaction,
              draft_action_type: Draft::CREATE,
              draft_changes: {
                "gender" => [
                  nil,
                  { const_type => Draft.name, const_id => new_gender.draft_pending_approval.id }
                ]
              }
            )
          end

          it "#new_value returns an the DraftChangesProxy's for the newly drafted values" do
            expected_values = [
              proxy.new(another_person.draft_pending_approval, transaction)
            ]
            expect(subject.new_value(association)).to match_array(expected_values)
          end

          it "#associations_added returns the DraftChangesProxy's for the newly drafted values" do
            expected_values = [
              proxy.new(another_person.draft_pending_approval, transaction)
            ]
            expect(subject.associations_added(association)).to match_array(expected_values)
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when a draft referencing the draftable has been created in another transaction' do
          let(:another_person) do
            FactoryBot.build(
              :person,
              :with_persisted_draft,
              draft_action_type: Draft::CREATE,
              draft_changes: {
                "gender" => [
                  nil,
                  { const_type => Draft.name, const_id => new_gender.draft_pending_approval.id }
                ]
              }
            )
          end

          it "#new_value returns an empty array" do
            expect(subject.new_value(association)).to match_array([])
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end
      end
    end

    context 'polymorphic has_many associations' do
      context 'when there is a draftable' do
        let(:subject)     { proxy.new(person, transaction) }
        let(:association) { "contact_addresses" }

        context 'when no additional drafts referencing the draftable have been created' do
          it "#new_value returns the DraftChangesProxy's for the current values" do
            expected_values = [proxy.new(contact, transaction)]
            expect(subject.new_value(association)).to match_array(expected_values)
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when an additional draft referencing the draftable has been created' do
          let(:another_contact) do
            FactoryBot.build(
              :contact_address,
              :with_persisted_draft,
              draft_transaction: transaction,
              draft_action_type: Draft::CREATE,
              draft_changes: {
                "contactable" => [
                  nil,
                  { const_type => Person.name, const_id => person.id }
                ]
              }
            )
          end

          it "#new_value returns an the DraftChangesProxy's for the current values and newly drafted values" do
            expected_values = [
              proxy.new(contact, transaction),
              proxy.new(another_contact.draft_pending_approval, transaction)
            ]
            expect(subject.new_value(association)).to match_array(expected_values)
          end

          it "#associations_added returns the DraftChangesProxy's for the newly drafted values" do
            expected_values = [
              proxy.new(another_contact.draft_pending_approval, transaction)
            ]
            expect(subject.associations_added(association)).to match_array(expected_values)
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when a draft referencing the draftable has been created in another transaction' do
          let(:another_contact) do
            FactoryBot.build(
              :contact_address,
              :with_persisted_draft,
              draft_action_type: Draft::CREATE,
              draft_changes: {
                "contactable" => [
                  nil,
                  { const_type => Person.name, const_id => person.id }
                ]
              }
            )
          end

          it "#new_value returns the DraftChangesProxy's for the current values" do
            expected_values = [proxy.new(contact, transaction)]
            expect(subject.new_value(association)).to match_array(expected_values)
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when a draft removing the draftable reference from the existing association has been created' do
          let!(:contact_draft) do
            FactoryBot.create(
              :draft,
              draft_transaction: transaction,
              draftable: contact,
              draft_action_type: Draft::UPDATE,
              draft_changes: {
                "contactable" => [
                  { const_type => Person.name, const_id => person.id },
                  nil
                ]
              }
            )
          end

          it "#new_value returns an empty array" do
            expect(subject.new_value(association)).to eql([])
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it "#associations_removed returns the DraftChangesProxy's for the draft" do
            expected_values = [proxy.new(contact, transaction)]
            expect(subject.associations_removed(association)).to match_array(expected_values)
          end
        end

        context 'when a draft deleting the associated object has been created' do
          let!(:contact_draft) do
            FactoryBot.create(
              :draft,
              draft_transaction: transaction,
              draftable: contact,
              draft_action_type: Draft::DELETE,
              draft_changes: {}
            )
          end

          it "#new_value returns an empty array" do
            expect(subject.new_value(association)).to eql([])
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it "#associations_removed returns the DraftChangesProxy's for the draft" do
            expected_values = [proxy.new(contact, transaction)]
            expect(subject.associations_removed(association)).to match_array(expected_values)
          end
        end
      end

      context 'when there is a Draft with no persisted draftable' do
        let(:new_person) do
          FactoryBot.build(
            :person,
            :with_persisted_draft,
            draft_transaction: transaction,
            draft_action_type: Draft::CREATE
          )
        end
        let(:subject)     { proxy.new(new_person.draft_pending_approval) }
        let(:association) { "contact_addresses" }

        context 'when no additional drafts referencing the subject draft have been created' do
          it '#new_value returns an empty array' do
            expect(subject.new_value(association)).to eql([])
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when an additional draft referencing the subject draft has been created' do
          let(:another_contact) do
            FactoryBot.build(
              :contact_address,
              :with_persisted_draft,
              draft_transaction: transaction,
              draft_action_type: Draft::CREATE,
              draft_changes: {
                "contactable" => [
                  nil,
                  { const_type => Draft.name, const_id => new_person.draft_pending_approval.id }
                ]
              }
            )
          end

          it "#new_value returns an the DraftChangesProxy's for the newly drafted values" do
            expected_values = [
              proxy.new(another_contact.draft_pending_approval, transaction)
            ]
            expect(subject.new_value(association)).to match_array(expected_values)
          end

          it "#associations_added returns the DraftChangesProxy's for the newly drafted values" do
            expected_values = [
              proxy.new(another_contact.draft_pending_approval, transaction)
            ]
            expect(subject.associations_added(association)).to match_array(expected_values)
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end

        context 'when a draft referencing the draftable has been created in another transaction' do
          let(:another_contact) do
            FactoryBot.build(
              :contact_address,
              :with_persisted_draft,
              draft_action_type: Draft::CREATE,
              draft_changes: {
                "contactable" => [
                  nil,
                  { const_type => Draft.name, const_id => new_person.draft_pending_approval.id }
                ]
              }
            )
          end

          it "#new_value returns an empty array" do
            expect(subject.new_value(association)).to match_array([])
          end

          it '#associations_added returns an empty array' do
            expect(subject.associations_added(association)).to eql([])
          end

          it '#associations_removed returns an empty array' do
            expect(subject.associations_removed(association)).to eql([])
          end
        end
      end
    end
  end
end
