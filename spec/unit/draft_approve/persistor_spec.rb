require 'spec_helper'

RSpec.describe DraftApprove::Persistor do
  let(:subject) { DraftApprove::Persistor }

  describe '.write_draft_from_model' do
    # The model & changes we use here are largely irrelevant to the tests, we just
    # need a model to create drafts of, and some known 'changes' that should get
    # saved to the database
    let(:model)   { FactoryBot.create(:role) }
    let(:changes) { { 'some_field' => ['old_value', 'new_value'] } }

    before(:each) do
      allow(DraftApprove::Serializers::Json).to receive(:changes_for_model).with(model).and_return(changes)
    end

    context 'when saving a draft with draft_action_type CREATE' do
      let(:action_type) { Draft::CREATE }

      context "when the model hasn't already been persisted" do
        let(:model) { FactoryBot.build(:role) }

        it 'creates a draft with fields set correctly' do
          draft = subject.write_draft_from_model(action_type, model)

          expect(draft.draftable_type).to eq('Role')
          expect(draft.draftable_id).to be(nil)
          expect(draft.draftable).to eq(model)
          expect(draft.draft_action_type).to eq(action_type)
          expect(draft.draft_changes).to eq(changes)
        end

        it 'persists the draft to the database with fields set correctly' do
          draft = subject.write_draft_from_model(action_type, model)

          expect(draft.persisted?).to be(true)
          draft.reload
          expect(draft.draftable_type).to eq('Role')
          expect(draft.draftable_id).to be(nil)
          expect(draft.draftable).to be(nil)
          expect(draft.draft_action_type).to eq(action_type)
          expect(draft.draft_changes).to eq(changes)
        end

        it 'sets the draft field on the model to the draft object' do
          draft = subject.write_draft_from_model(action_type, model)
          expect(model.draft_pending_approval).to eq(draft)
        end
      end

      context 'when the model has already been persisted' do
        it 'raises AlreadyPersistedModelError' do
          expect do
            subject.write_draft_from_model(action_type, model)
          end.to raise_error(DraftApprove::AlreadyPersistedModelError)
        end
      end
    end

    context 'when saving a draft with draft_action_type UPDATE' do
      let(:action_type) { Draft::UPDATE }

      context "when the model hasn't already been persisted" do
        let(:model) { FactoryBot.build(:role) }

        it 'raises UnpersistedModelError' do
          expect do
            subject.write_draft_from_model(action_type, model)
          end.to raise_error(DraftApprove::UnpersistedModelError)
        end
      end

      context 'when the model has already been persisted' do
        it 'creates a draft with fields set correctly' do
          draft = subject.write_draft_from_model(action_type, model)

          expect(draft.draftable_type).to eq('Role')
          expect(draft.draftable_id).to eq(model.id)
          expect(draft.draftable).to eq(model)
          expect(draft.draft_action_type).to eq(action_type)
          expect(draft.draft_changes).to eq(changes)
        end

        it 'persists the draft to the database with fields set correctly' do
          draft = subject.write_draft_from_model(action_type, model)

          expect(draft.persisted?).to be(true)
          draft.reload
          expect(draft.draftable_type).to eq('Role')
          expect(draft.draftable_id).to eq(model.id)
          expect(draft.draftable).to eq(model)
          expect(draft.draft_action_type).to eq(action_type)
          expect(draft.draft_changes).to eq(changes)
        end

        it 'sets the draft field on the model to the draft object' do
          draft = subject.write_draft_from_model(action_type, model)
          expect(model.draft_pending_approval).to eq(draft)
        end
      end
    end

    context 'when saving a draft with draft_action_type DELETE' do
      let(:action_type) { Draft::DELETE }

      context "when the model hasn't already been persisted" do
        let(:model) { FactoryBot.build(:role) }

        it 'raises UnpersistedModelError' do
          expect do
            subject.write_draft_from_model(action_type, model)
          end.to raise_error(DraftApprove::UnpersistedModelError)
        end
      end

      context 'when the model has already been persisted' do
        it 'creates a draft with fields set correctly' do
          draft = subject.write_draft_from_model(action_type, model)

          expect(draft.draftable_type).to eq('Role')
          expect(draft.draftable_id).to eq(model.id)
          expect(draft.draftable).to eq(model)
          expect(draft.draft_action_type).to eq(action_type)
          expect(draft.draft_changes).to eq(changes)
        end

        it 'persists the draft to the database with fields set correctly' do
          draft = subject.write_draft_from_model(action_type, model)

          expect(draft.persisted?).to be(true)
          draft.reload
          expect(draft.draftable_type).to eq('Role')
          expect(draft.draftable_id).to eq(model.id)
          expect(draft.draftable).to eq(model)
          expect(draft.draft_action_type).to eq(action_type)
          expect(draft.draft_changes).to eq(changes)
        end

        it 'sets the draft field on the model to the draft object' do
          draft = subject.write_draft_from_model(action_type, model)
          expect(model.draft_pending_approval).to eq(draft)
        end
      end
    end

    context 'when model has an existing draft' do
      let(:action_type) { Draft::UPDATE }  # Largely irrelevant, just any valid action type

      context 'when existing draft is pending approval' do
        let!(:existing_draft) { FactoryBot.create(:draft, :pending_approval, draftable: model) }

        it 'raises ExistingDraftError' do
          expect do
            subject.write_draft_from_model(action_type, model)
          end.to raise_error(DraftApprove::ExistingDraftError)
        end
      end

      context 'when existing draft is approved' do
        let!(:existing_draft) { FactoryBot.create(:draft, :approved, draftable: model) }

        it 'writes the draft to the database' do
          expect { subject.write_draft_from_model(action_type, model) }.to change { Draft.count }.by(1)
        end
      end

      context 'when existing draft is rejected' do
        let!(:existing_draft) { FactoryBot.create(:draft, :rejected, draftable: model) }

        it 'writes the draft to the database' do
          expect { subject.write_draft_from_model(action_type, model) }.to change { Draft.count }.by(1)
        end
      end
    end

    context 'when model is nil' do
      let(:action_type) { Draft::UPDATE }  # Largely irrelevant, just any valid action type

      it 'raises ArgumentError' do
        expect do
          subject.write_draft_from_model(action_type, nil)
        end.to raise_error(ArgumentError)
      end
    end

    context 'when draft_action_type is invalid' do
      let(:action_type) { 'some invalid action_type' }

      it 'raises ArgumentError' do
        expect do
          subject.write_draft_from_model(action_type, model)
        end.to raise_error(ArgumentError)
      end
    end

    context 'when draft_action_type is nil' do
      it 'raises ArgumentError' do
        expect do
          subject.write_draft_from_model(nil, model)
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe '.write_model_from_draft' do
    # The model / changes / serializer we use here are largely irrelevant to the tests,
    # we just need a model to be created/updated/deleted, and a known Serializer class
    # that will be called with the draft - we mock out the response so it returns the
    # expected new values
    let(:model)      { FactoryBot.create(:contact_address) }
    let(:serializer) { DraftApprove::Serializers::Json.name }

    let(:new_address_type) { FactoryBot.create(:contact_address_type) }
    let(:new_contactable)  { FactoryBot.create(:organization) }
    let(:new_label)        { 'a label for my contactable' }
    let(:new_value)        { 'a value for my contactable' }
    let(:new_values_hash) do
      {
        'contact_address_type' => new_address_type,
        'contactable' => new_contactable,
        'label' => new_label,
        'value' => new_value
      }
    end

    before(:each) do
      allow(DraftApprove::Serializers::Json).to receive(:new_values_for_draft).with(draft).and_return(new_values_hash)
    end

    context 'when writing a model from a CREATE draft' do
      let(:draft) do
        FactoryBot.create(
          :draft,
          draftable_type: model.class.name,
          draftable_id: nil,
          draft_action_type: Draft::CREATE,
          draft_serializer: serializer,
          draft_changes: {},  # Irrlevant, since new_values_for_draft is mocked
          draft_options: {}
        )
      end

      it 'writes a new model to the database' do
        expect { subject.write_model_from_draft(draft) }.to change { model.class.count }.by(1)
      end

      it 'updates the draft in the database to reference the newly created model' do
        new_model = subject.write_model_from_draft(draft)
        expect(draft.reload.draftable).to eq(new_model)
      end

      it 'returns the model with the expected values' do
        new_model = subject.write_model_from_draft(draft)
        expect(new_model.contact_address_type).to eq(new_address_type)
        expect(new_model.contactable).to eq(new_contactable)
        expect(new_model.label).to eq(new_label)
        expect(new_model.value).to eq(new_value)
      end

      it 'writes the expected values to the database' do
        new_model = subject.write_model_from_draft(draft)
        new_model.reload
        expect(new_model.contact_address_type).to eq(new_address_type)
        expect(new_model.contactable).to eq(new_contactable)
        expect(new_model.label).to eq(new_label)
        expect(new_model.value).to eq(new_value)
      end
    end

    context 'when writing a model from an UPDATE draft' do
      let(:draft) do
        FactoryBot.create(
          :draft,
          draftable: model,
          draft_action_type: Draft::UPDATE,
          draft_serializer: serializer,
          draft_changes: {},  # Irrlevant, since new_values_for_draft is mocked
          draft_options: {}
        )
      end

      it 'does not write a new model to the database' do
        expect { subject.write_model_from_draft(draft) }.not_to change { model.class.count }
      end

      it 'returns the model with the expected values' do
        changed_model = subject.write_model_from_draft(draft)
        expect(changed_model.contact_address_type).to eq(new_address_type)
        expect(changed_model.contactable).to eq(new_contactable)
        expect(changed_model.label).to eq(new_label)
        expect(changed_model.value).to eq(new_value)
      end

      it 'writes the expected values to the database' do
        changed_model = subject.write_model_from_draft(draft)
        changed_model.reload
        expect(changed_model.contact_address_type).to eq(new_address_type)
        expect(changed_model.contactable).to eq(new_contactable)
        expect(changed_model.label).to eq(new_label)
        expect(changed_model.value).to eq(new_value)
      end
    end

    context 'when writing a model from a DELETE draft' do
      let(:draft) do
        FactoryBot.create(
          :draft,
          draftable: model,
          draft_action_type: Draft::DELETE,
          draft_serializer: serializer,
          draft_changes: {},  # Irrlevant, since new_values_for_draft is mocked
          draft_options: {}
        )
      end

      it 'deletes a model from the database' do
        expect { subject.write_model_from_draft(draft) }.to change { model.class.count }.by(-1)
      end

      it 'returns the destroyed model' do
        changed_model = subject.write_model_from_draft(draft)
        expect(changed_model.destroyed?).to be(true)
      end

      it 'deletes the correct model from the database' do
        changed_model = subject.write_model_from_draft(draft)

        expect do
          changed_model.reload
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when writing a model from a draft with an unknown serializer' do
      let(:draft) do
        FactoryBot.create(
          :draft,
          draftable: model,
          draft_action_type: Draft::UPDATE,
          draft_serializer: 'DraftApprove::Serializers::NonExistantSerializer',
          draft_changes: {},  # Irrlevant, since new_values_for_draft is mocked
          draft_options: {}
        )
      end

      it 'raises a NameError' do
        expect do
          subject.write_model_from_draft(draft)
        end.to raise_error(NameError)
      end
    end

    context 'when writing a model from a draft with an unknown action_type' do
      let(:draft) do
        FactoryBot.create(
          :draft,
          :skip_validations,
          draftable: model,
          draft_action_type: 'NonExistantActionType',
          draft_serializer: serializer,
          draft_changes: {},  # Irrlevant, since new_values_for_draft is mocked
          draft_options: {}
        )
      end

      it 'raises an ArgumentError' do
        expect do
          subject.write_model_from_draft(draft)
        end.to raise_error(ArgumentError)
      end
    end
  end
end
