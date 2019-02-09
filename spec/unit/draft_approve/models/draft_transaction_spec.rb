require 'spec_helper'

RSpec.describe DraftTransaction do
  let(:subject) { FactoryBot.create(:draft_transaction) }

  describe '#approve_changes!' do
    let!(:draft)   { FactoryBot.create(:draft, draft_transaction: subject) }

    before do
      allow_any_instance_of(Draft).to receive(:apply_changes).and_return(:true)
    end

    context 'when no error occurs while approving the changes' do
      it 'updates the status of the draft transaction to approved' do
        subject.approve_changes!
        expect(subject.reload.status).to eq(DraftTransaction::APPROVED)
      end

      context 'when reviewed_by is set' do
        let(:reviewed_by) { 'the user who approved it' }

        it 'updates the reviewed_by on the draft transaction' do
          subject.approve_changes!(reviewed_by: reviewed_by)
          expect(subject.reload.reviewed_by).to eq(reviewed_by)
        end
      end

      context 'when a review_reason is set' do
        let(:review_reason) { 'the reason for approving it' }

        it 'updates the review_reason on the draft transaction' do
          subject.approve_changes!(review_reason: review_reason)
          expect(subject.reload.review_reason).to eq(review_reason)
        end
      end
    end

    context 'when an error occurs while approving the changes' do
      before do
        allow_any_instance_of(Draft).to receive(:apply_changes).and_raise(TestError)
      end

      it 're-raises the error' do
        expect do
          subject.approve_changes!
        end.to raise_error(TestError)
      end

      it 'updates the status of the draft transaction to approval error' do
        begin
          subject.approve_changes!
        rescue
          # Prevent the expected exception from killing the test
        end

        expect(subject.reload.status).to eq(DraftTransaction::APPROVAL_ERROR)
      end

      it 'sets the error column on the draft transaction' do
        begin
          subject.approve_changes!
        rescue
          # Prevent the expected exception from killing the test
        end

        expect(subject.reload.error).to include(TestError.name)
      end
    end
  end

  describe '#reject_changes' do
    it 'updates the status of the draft transaction to rejected' do
      subject.reject_changes
      expect(subject.reload.status).to eq(DraftTransaction::REJECTED)
    end

    context 'when reviewed_by is set' do
      let(:reviewed_by) { 'the user who rejected it' }

      it 'updates the reviewed_by on the draft transaction' do
        subject.reject_changes(reviewed_by: reviewed_by)
        expect(subject.reload.reviewed_by).to eq(reviewed_by)
      end
    end

    context 'when a review_reason is set' do
      let(:review_reason) { 'the reason for approving it' }

      it 'updates the review_reason on the draft transaction' do
        subject.reject_changes(review_reason: review_reason)
        expect(subject.reload.review_reason).to eq(review_reason)
      end
    end
  end
end

class TestError < StandardError; end
