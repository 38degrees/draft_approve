require 'spec_helper'

RSpec.describe 'Draft Approve Scenario Tests', integration: true do
  context 'when not using an explicit Draft Approve Transaction' do
    let(:role_name) { 'integration test role name' }

    context 'when creating a new record' do
      it 'creates the new record when the draft is approved' do
        # Declare draft so we have reference to it outside the first expect block
        draft = nil

        # Create the draft
        expect do
          draft = Role.new(name: role_name).save_draft!
        end.to change { Draft.count }.by(1).and change { DraftTransaction.count }.by(1)

        # Approve the draft
        expect do
          draft.draft_transaction.approve_changes
        end.to change { Role.count }.by(1)

        expect(Role.where(name: role_name).count).to eq(1)
      end
    end

    context 'when updating an existing record' do
      let(:model) { FactoryBot.create(:role) }

      it 'creates the new record when the draft is approved' do
        # Declare draft so we have reference to it outside the first expect block
        draft = nil

        # Create the draft
        expect do
          model.name = role_name
          draft = model.save_draft!
        end.to change { Draft.count }.by(1).and change { DraftTransaction.count }.by(1)

        # Approve the draft
        expect do
          draft.draft_transaction.approve_changes
        end.not_to change { Role.count }

        expect(Role.where(name: role_name).count).to eq(1)
      end
    end
  end
end
