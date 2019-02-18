require 'spec_helper'

RSpec.describe DraftApprove::Serialization::Json::Serializer do
  let(:subject) { DraftApprove::Serialization::Json::Serializer }

  let(:const_type) { subject::TYPE }
  let(:const_id)   { subject::ID }

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
                { const_type => 'Person', const_id => person.id },
                { const_type => 'Person', const_id => new_person.id }
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
                  { const_type => 'Person', const_id => person.id },
                  { const_type => 'Draft', const_id => new_person.draft_pending_approval.id }
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
              'person' => [{ const_type => 'Person', const_id => person.id }, nil]
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
                { const_type => 'Person', const_id => person.id },
                { const_type => 'Person', const_id => new_person.id }
              ],
              'organization' => [
                { const_type => 'Organization', const_id => org.id },
                { const_type => 'Draft', const_id => new_org.draft_pending_approval.id }
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
              'person' => [nil, { const_type => 'Person', const_id => person.id }],
              'organization' => [nil, { const_type => 'Organization', const_id => org.id } ]
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
              'person' => [nil, { const_type => 'Draft', const_id => new_person.draft_pending_approval.id }],
              'organization' => [nil, { const_type => 'Draft', const_id => new_org.draft_pending_approval.id } ]
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
                { const_type => 'Person', const_id => person.id },
                { const_type => 'Person', const_id => new_person.id }
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
                  { const_type => 'Person', const_id => person.id },
                  { const_type => 'Draft', const_id => new_person.draft_pending_approval.id }
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
              'contactable' => [{ const_type => 'Person', const_id => person.id }, nil]
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
                { const_type => 'Person', const_id => person.id },
                { const_type => 'Draft', const_id => new_person.draft_pending_approval.id }
              ],
              'contact_address_type' => [
                { const_type => 'ContactAddressType', const_id => contact_type.id },
                { const_type => 'ContactAddressType', const_id => new_contact_type.id }
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
                { const_type => 'Person', const_id => person.id }
              ],
              'contact_address_type' => [
                nil,
                { const_type => 'ContactAddressType', const_id => contact_type.id }
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
                { const_type => 'Draft', const_id => new_person.draft_pending_approval.id }
              ],
              'contact_address_type' => [
                nil,
                { const_type => 'Draft', const_id => new_contact_type.draft_pending_approval.id }
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

  describe '.new_values_for_draft' do
    let(:draft) { FactoryBot.create(:draft, draftable_type: model.class.name, draftable_id: model.id, draft_changes: changes) }

    context 'when changes is empty' do
      let(:model) { FactoryBot.create(:gender) }
      let(:changes) { {} }
      it 'returns an empty hash' do
        expect(subject.new_values_for_draft(draft)).to eq({})
      end
    end

    context 'when only simple attributes have changes' do
      let(:model) { FactoryBot.create(:gender) }

      context 'when a single attribute has changed' do
        let(:new_name) { 'Some new name' }
        let(:changes) { { 'name' => [model.name, new_name] } }

        let(:expected_hash) { { 'name' => new_name } }

        it 'returns a hash with the changed attribute and its expected new value' do
          expect(subject.new_values_for_draft(draft)).to eq(expected_hash)
        end
      end

      context 'when multiple attributes have changed' do
        let(:new_name) { 'Some new name' }
        let(:new_title) { 'Some new title' }
        let(:changes) { { 'name' => [model.name, new_name], 'commonly_used_title' => [model.commonly_used_title, new_title] } }

        let(:expected_hash) { { 'name' => new_name, 'commonly_used_title' => new_title } }

        it 'returns a hash with the changed attributes and their expected new values' do
          expect(subject.new_values_for_draft(draft)).to eq(expected_hash)
        end
      end

      context 'when a single attribute has been changed to nil' do
        let(:model) { FactoryBot.create(:gender, commonly_used_title: 'Some title') }
        let(:changes) { { 'commonly_used_title' => [model.commonly_used_title, nil] } }

        let(:expected_hash) { { 'commonly_used_title' => nil } }

        it 'returns a hash with the changed attribute and a nil value' do
          expect(subject.new_values_for_draft(draft)).to eq(expected_hash)
        end
      end
    end

    context 'when associations have changes' do
      let(:model) { FactoryBot.create(:membership) }

      context 'when a single association has changed' do
        context 'when the new value is nil' do
          let(:changes) do
            {
              'person' => [
                { const_type => model.person.class.name, const_id => model.person.id },
                nil
              ]
            }
          end

          let(:expected_hash) { { 'person' => nil } }

          it 'returns a hash with the changed association and a nil value' do
            expect(subject.new_values_for_draft(draft)).to eq(expected_hash)
          end
        end

        context 'when the new value points to a non-draft object' do
          context 'when the non-draft object exists' do
            let(:new_person) { FactoryBot.create(:person) }
            let(:changes) do
              {
                'person' => [
                  { const_type => model.person.class.name, const_id => model.person.id },
                  { const_type => new_person.class.name, const_id => new_person.id }
                ]
              }
            end

            let(:expected_hash) { { 'person' => new_person } }

            it 'returns a hash with the changed association and its expected new value' do
              expect(subject.new_values_for_draft(draft)).to eq(expected_hash)
            end
          end

          context "when the non-draft type doesn't exist" do
            let(:changes) do
              {
                'person' => [
                  { const_type => model.person.class.name, const_id => model.person.id },
                  { const_type => 'MyNonExistentClass', const_id => 1 }
                ]
              }
            end

            it 'raises a NameError' do
              expect do
                subject.new_values_for_draft(draft)
              end.to raise_error(NameError)
            end
          end

          context "when the non-draft object doesn't exist" do
            let(:new_person) { FactoryBot.create(:person) }
            let(:changes) do
              {
                'person' => [
                  { const_type => model.person.class.name, const_id => model.person.id },
                  { const_type => 'Person', const_id => (new_person.id + 1) } # Force the ID to be 1 greater so no record will be found
                ]
              }
            end

            it 'raises a RecordNotFound error' do
              expect do
                subject.new_values_for_draft(draft)
              end.to raise_error(ActiveRecord::RecordNotFound)
            end
          end
        end

        context 'when the new value points to a draft object' do
          let(:other_draft) { FactoryBot.create(:draft) }

          context 'when the draft object exists in the same transaction' do
            context 'when the draft points to a persisted draftable' do
              let(:new_person) { FactoryBot.create(:person) }

              let(:changes) do
                {
                  'person' => [
                    { const_type => model.person.class.name, const_id => model.person.id },
                    { const_type => other_draft.class.name, const_id => other_draft.id }
                  ]
                }
              end

              let(:expected_hash) { { 'person' => new_person } }

              before do
                # If we do this in a `let` it causes cyclic `let` dependencies!
                other_draft.update!(draft_transaction: draft.draft_transaction, draftable: new_person)
              end

              it 'returns a hash with the changed association and its expected new value' do
                expect(subject.new_values_for_draft(draft)).to eq(expected_hash)
              end
            end

            context 'when the draft points to a non-persisted draftable' do
              let(:new_person) { FactoryBot.build(:person) }

              let(:changes) do
                {
                  'person' => [
                    { const_type => model.person.class.name, const_id => model.person.id },
                    { const_type => other_draft.class.name, const_id => other_draft.id }
                  ]
                }
              end

              let(:expected_hash) { { 'person' => new_person } }

              before do
                # If we do this in a `let` it causes cyclic `let` dependencies!
                other_draft.update!(
                  draft_transaction: draft.draft_transaction,
                  draftable_type: 'Person',
                  draftable_id: nil
                )

                # Doing this in the `update!` writes new_person to the DB, which we don't want for this test!
                other_draft.draftable = new_person
              end

              it 'raises a PriorDraftNotAppliedError' do
                expect do
                  subject.new_values_for_draft(draft)
                end.to raise_error(DraftApprove::PriorDraftNotAppliedError)
              end
            end

            context 'when the draft does not point to a draftable' do
              let(:changes) do
                {
                  'person' => [
                    { const_type => model.person.class.name, const_id => model.person.id },
                    { const_type => other_draft.class.name, const_id => other_draft.id }
                  ]
                }
              end

              before do
                # If we do this in a `let` it causes cyclic `let` dependencies!
                other_draft.update!(draft_transaction: draft.draft_transaction, draftable: nil)
              end

              it 'raises a PriorDraftNotAppliedError' do
                expect do
                  subject.new_values_for_draft(draft)
                end.to raise_error(DraftApprove::PriorDraftNotAppliedError)
              end
            end
          end

          context 'when the draft object exists in a different transaction' do
            let(:other_draft) { FactoryBot.create(:draft) }
            let(:changes) do
              {
                'person' => [
                  { const_type => model.person.class.name, const_id => model.person.id },
                  { const_type => other_draft.class.name, const_id => other_draft.id }
                ]
              }
            end

            it 'raises a RecordNotFound' do
              expect do
                subject.new_values_for_draft(draft)
              end.to raise_error(ActiveRecord::RecordNotFound)
            end
          end

          context 'when the draft object does not exist' do
            let(:changes) do
              {
                'person' => [
                  { const_type => model.person.class.name, const_id => model.person.id },
                  { const_type => 'Draft', const_id => nil }
                ]
              }
            end

            it 'raises a RecordNotFound' do
              expect do
                subject.new_values_for_draft(draft)
              end.to raise_error(ActiveRecord::RecordNotFound)
            end
          end
        end
      end

      context 'when multiple associations have changed' do
        let(:new_person) { FactoryBot.create(:person) }
        let(:new_org)    { FactoryBot.create(:organization) }
        let(:new_role)   { FactoryBot.create(:role) }

        let(:new_person_draft) { FactoryBot.create(:draft, draftable: new_person) }
        let(:new_org_draft)    { FactoryBot.create(:draft, draftable: new_org) }

        let(:changes) do
          {
            'person' => [
              { const_type => model.person.class.name, const_id => model.person.id },
              { const_type => new_person_draft.class.name, const_id => new_person_draft.id }
            ],
            'organization' => [
              { const_type => model.organization.class.name, const_id => model.organization.id },
              { const_type => new_org_draft.class.name, const_id => new_org_draft.id }
            ],
            'role' => [
              { const_type => nil, const_id => nil },
              { const_type => new_role.class.name, const_id => new_role.id }
            ]
          }
        end

        let(:expected_hash) { { 'person' => new_person, 'organization' => new_org, 'role' => new_role } }

        before do
          # If we do this in a `let` it causes cyclic `let` dependencies!
          new_person_draft.update!(draft_transaction: draft.draft_transaction)
          new_org_draft.update!(draft_transaction: draft.draft_transaction)
        end

        it 'returns a hash with the changed associations and all expected new values' do
          expect(subject.new_values_for_draft(draft)).to eq(expected_hash)
        end
      end
    end

    # Test a model with normal attribute, non-polymorphic association, polymorphic association
    context 'when a combination of attribute types have changes' do
      let(:model) { FactoryBot.create(:contact_address) }

      let(:new_contactable) { FactoryBot.create(:membership) }
      let(:new_label)       { "Some New Label" }
      let(:new_value)       { "Some New Value" }

      let(:new_contactable_draft) { FactoryBot.create(:draft, draftable: new_contactable) }

      let(:changes) do
        {
          'contact_address_type' => [
            { const_type => model.contact_address_type.class.name, const_id => model.contact_address_type.id },
            nil
          ],
          'contactable' => [
            { const_type => model.contactable.class.name, const_id => model.contactable.id },
            { const_type => new_contactable_draft.class.name, const_id => new_contactable_draft.id }
          ],
          'label' => [nil, new_label],
          'value' => [model.value, new_value]
        }
      end

      let(:expected_hash) do
        {
          'contact_address_type' => nil,
          'contactable' => new_contactable,
          'label' => new_label,
          'value' => new_value
        }
      end

      before do
        # If we do this in a `let` it causes cyclic `let` dependencies!
        new_contactable_draft.update!(draft_transaction: draft.draft_transaction)
      end

      it 'returns a hash with the changed associations and all expected new values' do
        expect(subject.new_values_for_draft(draft)).to eq(expected_hash)
      end
    end
  end
end
