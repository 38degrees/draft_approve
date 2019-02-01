require 'spec_helper'

RSpec.describe DraftApprove::Serializers::Json do
  let(:subject) { DraftApprove::Serializers::Json }

  describe '.changes_for_model' do
    context 'when using a model with no associations' do
      context 'when model is already persisted' do
        let(:old_name) { 'old_name' }
        let(:old_title) { 'old_title' }
        let(:model) { FactoryBot.create(:gender, name: old_name, commonly_used_title: old_title) }

        context 'when model has no changes' do
          it 'returns an empty hash' do
            expect(subject.changes_for_model(model)).to eq({})
          end
        end

        context 'when model has a single change' do
          let(:new_name) { 'Female' }
          let(:expected_changes) { { 'name' => [old_name, new_name] } }

          before(:each) do
            model.name = new_name
          end

          it 'returns a hash containing the change' do
            expect(subject.changes_for_model(model)).to eq(expected_changes)
          end
        end

        context 'when model has multiple changes' do
          let(:new_name) { 'Male' }
          let(:new_title) { 'Mr' }
          let(:expected_changes) do
            {
              'name' => [old_name, new_name],
              'commonly_used_title' => [old_title, new_title]
            }
          end

          before(:each) do
            model.name = new_name
            model.commonly_used_title = new_title
          end

          it 'returns a hash containing all the changes' do
            expect(subject.changes_for_model(model)).to eq(expected_changes)
          end
        end
      end

      context 'when model is not yet persisted' do
        let(:old_name) { 'old_name' }
        let(:old_title) { 'old_title' }
        let(:model) { FactoryBot.build(:gender, name: old_name, commonly_used_title: old_title) }

        context 'when model has no changes since being instantiated' do
          let(:expected_changes) do
            {
              'name' => [nil, old_name],
              'commonly_used_title' => [nil, old_title]
            }
          end

          it 'returns a hash containing all attributes which have been set' do
            expect(subject.changes_for_model(model)).to eq(expected_changes)
          end
        end

        context 'when model has changes since being instantiated' do
          let(:new_name) { 'Male' }
          let(:new_title) { 'Mr' }
          let(:expected_changes) do
            {
              'name' => [nil, new_name],
              'commonly_used_title' => [nil, new_title]
            }
          end

          before(:each) do
            model.name = new_name
            model.commonly_used_title = new_title
          end

          it 'returns a hash containing the latest values for all attributes which have been set' do
            expect(subject.changes_for_model(model)).to eq(expected_changes)
          end
        end
      end
    end

    context 'when using a model with non-polymorphic associations' do
      context 'when model is already persisted' do
        let(:person)     { FactoryBot.create(:person) }
        let(:org)        { FactoryBot.create(:organization) }
        let(:membership) { FactoryBot.create(:membership, person: person, organization: org) }

        context 'when model has no changes' do
          it 'returns an empty hash' do
            expect(subject.changes_for_model(membership)).to eq({})
          end
        end

        context 'when model is changed to reference a persisted model' do
          let(:expected_changes) do
            {
              'person' => [
                { DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id },
                { DraftApprove::TYPE => 'Person', DraftApprove::ID => new_person.id }
              ]
            }
          end

          context 'when new model has no draft' do
            let(:new_person) { FactoryBot.create(:person) }

            it 'returns changes referencing the persisted model' do
              membership.person = new_person
              expect(subject.changes_for_model(membership)).to eq(expected_changes)
            end
          end

          context 'when new model has an unpersisted draft' do
            let(:new_person) { FactoryBot.create(:person, :with_unpersisted_draft) }

            it 'returns changes referencing the persisted model' do
              membership.person = new_person
              expect(subject.changes_for_model(membership)).to eq(expected_changes)
            end
          end

          context 'when new model has a persisted draft' do
            let(:new_person) { FactoryBot.create(:person, :with_persisted_draft) }

            it 'returns changes referencing the persisted model' do
              membership.person = new_person
              expect(subject.changes_for_model(membership)).to eq(expected_changes)
            end
          end
        end

        context 'when model is changed to reference an unpersisted model' do
          context 'when new model has no draft' do
            let(:new_person) { FactoryBot.build(:person) }

            it 'raises an AssociationUnsavedError' do
              membership.person = new_person
              expect do
                subject.changes_for_model(membership)
              end.to raise_error(DraftApprove::AssociationUnsavedError)
            end
          end

          context 'when new model has an unpersisted draft' do
            let(:new_person) { FactoryBot.build(:person, :with_unpersisted_draft) }

            it 'raises an AssociationUnsavedError' do
              membership.person = new_person
              expect do
                subject.changes_for_model(membership)
              end.to raise_error(DraftApprove::AssociationUnsavedError)
            end
          end

          context 'when new model has a persisted draft' do
            let(:new_person) { FactoryBot.build(:person, :with_persisted_draft) }
            let(:expected_changes) do
              {
                'person' => [
                  { DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id },
                  { DraftApprove::TYPE => 'Draft', DraftApprove::ID => new_person.draft.id }
                ]
              }
            end

            it 'returns changes referencing the persisted model' do
              membership.person = new_person
              expect(subject.changes_for_model(membership)).to eq(expected_changes)
            end
          end
        end

        context 'when model is changed to reference nil' do
          let(:expected_changes) do
            {
              'person' => [{ DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id }, nil]
            }
          end

          it 'returns changes referencing the persisted model' do
            membership.person = nil
            expect(subject.changes_for_model(membership)).to eq(expected_changes)
          end
        end

        context 'when model has multiple changes' do
          let(:new_person) { FactoryBot.create(:person) }
          let(:new_org)    { FactoryBot.build(:organization, :with_persisted_draft) }
          let(:expected_changes) do
            {
              'person' => [
                { DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id },
                { DraftApprove::TYPE => 'Person', DraftApprove::ID => new_person.id }
              ],
              'organization' => [
                { DraftApprove::TYPE => 'Organization', DraftApprove::ID => org.id },
                { DraftApprove::TYPE => 'Draft', DraftApprove::ID => new_org.draft.id }
              ]
            }
          end

          it 'returns the changes to all changed associations' do
            membership.person = new_person
            membership.organization = new_org
            expect(subject.changes_for_model(membership)).to eq(expected_changes)
          end
        end
      end

      context 'when model is not yet persisted' do
        let(:person)     { FactoryBot.create(:person) }
        let(:org)        { FactoryBot.create(:organization) }
        let(:membership) { FactoryBot.build(:membership, person: person, organization: org) }

        context 'when model has no changes since being instantiated' do
          let(:expected_changes) do
            {
              'person' => [nil, { DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id }],
              'organization' => [nil, { DraftApprove::TYPE => 'Organization', DraftApprove::ID => org.id } ]
            }
          end

          it 'returns changes with nil old values and new values referencing the associated models' do
            expect(subject.changes_for_model(membership)).to eq(expected_changes)
          end
        end

        context 'when model is changed to reference unpersisted models with drafts' do
          let(:new_person) { FactoryBot.build(:person, :with_persisted_draft) }
          let(:new_org)    { FactoryBot.build(:organization, :with_persisted_draft) }
          let(:expected_changes) do
            {
              'person' => [nil, { DraftApprove::TYPE => 'Draft', DraftApprove::ID => new_person.draft.id }],
              'organization' => [nil, { DraftApprove::TYPE => 'Draft', DraftApprove::ID => new_org.draft.id } ]
            }
          end

          it 'returns changes with nil old values and new values referencing the new associated drafts' do
            membership.person = new_person
            membership.organization = new_org
            expect(subject.changes_for_model(membership)).to eq(expected_changes)
          end
        end
      end
    end

    context 'when using a model with a polymorphic association' do
      context 'when model is already persisted' do
        let(:contact_type) { FactoryBot.create(:contact_address_type) }
        let(:person)       { FactoryBot.create(:person) }
        let(:contact)      { FactoryBot.create(:contact_address, contact_address_type: contact_type, contactable: person) }

        context 'when model has no changes' do
          it 'returns an empty hash' do
            expect(subject.changes_for_model(contact)).to eq({})
          end
        end

        context 'when model is changed to reference a persisted model' do
          let(:expected_changes) do
            {
              'contactable' => [
                { DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id },
                { DraftApprove::TYPE => 'Person', DraftApprove::ID => new_person.id }
              ]
            }
          end

          context 'when new model has no draft' do
            let(:new_person) { FactoryBot.create(:person) }

            it 'returns changes referencing the persisted model' do
              contact.contactable = new_person
              expect(subject.changes_for_model(contact)).to eq(expected_changes)
            end
          end

          context 'when new model has an unpersisted draft' do
            let(:new_person) { FactoryBot.create(:person, :with_unpersisted_draft) }

            it 'returns changes referencing the persisted model' do
              contact.contactable = new_person
              expect(subject.changes_for_model(contact)).to eq(expected_changes)
            end
          end

          context 'when new model has a persisted draft' do
            let(:new_person) { FactoryBot.create(:person, :with_persisted_draft) }

            it 'returns changes referencing the persisted model' do
              contact.contactable = new_person
              expect(subject.changes_for_model(contact)).to eq(expected_changes)
            end
          end
        end

        context 'when model is changed to reference an unpersisted model' do
          context 'when new model has no draft' do
            let(:new_person) { FactoryBot.build(:person) }

            it 'raises an AssociationUnsavedError' do
              contact.contactable = new_person
              expect do
                subject.changes_for_model(contact)
              end.to raise_error(DraftApprove::AssociationUnsavedError)
            end
          end

          context 'when new model has an unpersisted draft' do
            let(:new_person) { FactoryBot.build(:person, :with_unpersisted_draft) }

            it 'raises an AssociationUnsavedError' do
              contact.contactable = new_person
              expect do
                subject.changes_for_model(contact)
              end.to raise_error(DraftApprove::AssociationUnsavedError)
            end
          end

          context 'when new model has a persisted draft' do
            let(:new_person) { FactoryBot.build(:person, :with_persisted_draft) }
            let(:expected_changes) do
              {
                'contactable' => [
                  { DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id },
                  { DraftApprove::TYPE => 'Draft', DraftApprove::ID => new_person.draft.id }
                ]
              }
            end

            it 'returns changes referencing the persisted model' do
              contact.contactable = new_person
              expect(subject.changes_for_model(contact)).to eq(expected_changes)
            end
          end
        end

        context 'when model is changed to reference nil' do
          let(:expected_changes) do
            {
              'contactable' => [{ DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id }, nil]
            }
          end

          it 'returns changes referencing the persisted model' do
            contact.contactable = nil
            expect(subject.changes_for_model(contact)).to eq(expected_changes)
          end
        end

        context 'when model has multiple changes' do
          let(:new_person)       { FactoryBot.build(:person, :with_persisted_draft) }
          let(:new_contact_type) { FactoryBot.create(:contact_address_type) }
          let(:expected_changes) do
            {
              'contactable' => [
                { DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id },
                { DraftApprove::TYPE => 'Draft', DraftApprove::ID => new_person.draft.id }
              ],
              'contact_address_type' => [
                { DraftApprove::TYPE => 'ContactAddressType', DraftApprove::ID => contact_type.id },
                { DraftApprove::TYPE => 'ContactAddressType', DraftApprove::ID => new_contact_type.id }
              ]
            }
          end

          it 'returns the changes to all changed associations' do
            contact.contactable = new_person
            contact.contact_address_type = new_contact_type
            expect(subject.changes_for_model(contact)).to eq(expected_changes)
          end
        end
      end

      context 'when model is not yet persisted' do
        let(:contact_type) { FactoryBot.create(:contact_address_type) }
        let(:person)       { FactoryBot.create(:person) }
        let(:contact)      { FactoryBot.build(:contact_address, contact_address_type: contact_type, contactable: person) }

        context 'when model has no changes since being instantiated' do
          let(:expected_changes) do
            {
              'contactable' => [
                nil,
                { DraftApprove::TYPE => 'Person', DraftApprove::ID => person.id }
              ],
              'contact_address_type' => [
                nil,
                { DraftApprove::TYPE => 'ContactAddressType', DraftApprove::ID => contact_type.id }
              ],
              'value' => [nil, contact.value]
            }
          end

          it 'returns changes with nil old values and new values referencing the associated models' do
            expect(subject.changes_for_model(contact)).to eq(expected_changes)
          end
        end

        context 'when model is changed to reference unpersisted models with drafts' do
          let(:new_person)       { FactoryBot.build(:person, :with_persisted_draft) }
          let(:new_contact_type) { FactoryBot.build(:contact_address_type, :with_persisted_draft) }
          let(:expected_changes) do
            {
              'contactable' => [
                nil,
                { DraftApprove::TYPE => 'Draft', DraftApprove::ID => new_person.draft.id }
              ],
              'contact_address_type' => [
                nil,
                { DraftApprove::TYPE => 'Draft', DraftApprove::ID => new_contact_type.draft.id }
              ],
              'value' => [nil, contact.value]
            }
          end

          it 'returns changes with nil old values and new values referencing the new associated drafts' do
            contact.contactable = new_person
            contact.contact_address_type = new_contact_type
            expect(subject.changes_for_model(contact)).to eq(expected_changes)
          end
        end
      end
    end
  end
end
