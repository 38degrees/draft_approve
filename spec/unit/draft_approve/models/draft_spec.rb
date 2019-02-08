require 'spec_helper'

RSpec.describe Draft do
  context 'scopes' do
    let!(:pending_draft)  { FactoryBot.create(:draft, :pending_approval) }
    let!(:approved_draft) { FactoryBot.create(:draft, :approved) }
    let!(:rejected_draft) { FactoryBot.create(:draft, :rejected) }
    let!(:error_draft)    { FactoryBot.create(:draft, :approval_error) }

    describe '.pending_approval' do
      it 'returns one draft' do
        expect(Draft.pending_approval.count).to eq(1)
      end

      it 'returns the correct draft' do
        expect(Draft.pending_approval.first).to eq(pending_draft)
      end
    end

    describe '.approved' do
      it 'returns one draft' do
        expect(Draft.approved.count).to eq(1)
      end

      it 'returns the correct draft' do
        expect(Draft.approved.first).to eq(approved_draft)
      end
    end

    describe '.rejected' do
      it 'returns one draft' do
        expect(Draft.rejected.count).to eq(1)
      end

      it 'returns the correct draft' do
        expect(Draft.rejected.first).to eq(rejected_draft)
      end
    end

    describe '.approval_error' do
      it 'returns one draft' do
        expect(Draft.approval_error.count).to eq(1)
      end

      it 'returns the correct draft' do
        expect(Draft.approval_error.first).to eq(error_draft)
      end
    end
  end
end
