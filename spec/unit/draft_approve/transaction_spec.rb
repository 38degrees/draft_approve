require 'spec_helper'

RSpec.describe DraftApprove::Transaction do
  let(:subject) { DraftApprove::Transaction }
  let(:dummy_record_name) { 'some_dummy_record' }

  describe '.in_new_draft_transaction' do
    context 'when no existing draft transaction' do
      context 'when no error occurs in the given block' do
        it 'creates a DraftTransaction record' do
          expect do
            subject.in_new_draft_transaction { true }
          end.to change { DraftTransaction.count }.by(1)
        end

        it 'creates a DraftTransaction with the correct status' do
          draft_transaction = subject.in_new_draft_transaction { true }
          expect(draft_transaction.status).to eq(DraftTransaction::PENDING_APPROVAL)
        end

        it 'executes the code in the block successfully' do
          expect do
            subject.in_new_draft_transaction do
              create_dummy_record!(dummy_record_name)
            end
          end.to change { dummy_record_count(dummy_record_name) }.by(1)
        end
      end

      context 'when an error occurs in the given block' do
        it 'does not create a DraftTransaction record if an error is raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              raise(ActiveRecord::Rollback, "Error to force a rollback")
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'rolls back the transaction if an error is raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              create_dummy_record!(dummy_record_name)
              raise(ActiveRecord::Rollback, "Error to force a rollback")
            end
          end.not_to change { dummy_record_count(dummy_record_name) }
        end
      end
    end

    context 'when a draft transaction already exists in this thread' do
      around(:each) do |example|
        subject.in_new_draft_transaction do
          example.run
        end
      end

      it 'raises a NestedDraftTransactionError' do
        expect do
          subject.in_new_draft_transaction { true }
        end.to raise_error(DraftApprove::NestedDraftTransactionError)
      end

      it 'does not create a DraftTransaction record' do
        expect do
          begin
            subject.in_new_draft_transaction { true }
          rescue
            # Prevent the NestedDraftTransactionError getting thrown up to rspec
          end
        end.not_to change { DraftTransaction.count }
      end
    end

    context 'when a draft transaction exists in another thread' do
      around(:each) do |example|
        other_thread = Fiber.new do
          subject.in_new_draft_transaction do
            # Wait inside the transaction until other_thread.resume is called
            Fiber.yield
          end
        end

        other_thread.resume # run other_thread up to Fiber.yield...
        example.run
        other_thread.resume # wake up other_thread so it can complete...
      end

      it 'creates a DraftTransaction record' do
        expect do
          subject.in_new_draft_transaction { true }
        end.to change { DraftTransaction.count }.by(1)
      end

      it 'executes the code in the block successfully' do
        expect do
          subject.in_new_draft_transaction do
            create_dummy_record!(dummy_record_name)
          end
        end.to change { dummy_record_count(dummy_record_name) }.by(1)
      end
    end
  end

  describe '.ensure_in_draft_transaction' do
    context 'when no existing draft transaction' do
      context 'when no error occurs in the given block' do
        it 'creates a DraftTransaction record' do
          expect do
            subject.ensure_in_draft_transaction { true }
          end.to change { DraftTransaction.count }.by(1)
        end

        it 'executes the code in the block successfully' do
          expect do
            subject.ensure_in_draft_transaction do
              create_dummy_record!(dummy_record_name)
            end
          end.to change { dummy_record_count(dummy_record_name) }.by(1)
        end
      end

      context 'when an error occurs in the given block' do
        it 'does not create a DraftTransaction record if an error is raised in the block' do
          expect do
            subject.ensure_in_draft_transaction do
              raise(ActiveRecord::Rollback, "Error to force a rollback")
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'rolls back the transaction if an error is raised in the block' do
          expect do
            subject.ensure_in_draft_transaction do
              create_dummy_record!(dummy_record_name)
              raise(ActiveRecord::Rollback, "Error to force a rollback")
            end
          end.not_to change { dummy_record_count(dummy_record_name) }
        end
      end
    end

    context 'when a draft transaction already exists in this thread' do
      context 'when no error occurs in the given block' do
        around(:each) do |example|
          subject.in_new_draft_transaction do
            example.run
          end
        end

        it 'does not create a new DraftTransaction record' do
          expect do
            subject.ensure_in_draft_transaction { true }
          end.not_to change { DraftTransaction.count }
        end

        it 'executes the code in the block successfully' do
          expect do
            subject.ensure_in_draft_transaction do
              create_dummy_record!(dummy_record_name)
            end
          end.to change { dummy_record_count(dummy_record_name) }.by(1)
        end
      end

      context 'when an error occurs in the given block' do
        # In this context we can't put the outer transaction in an around(:each)
        # because we need to test the outer transaction is rolled back.
        # Putting the in_new_draft_transaction call into an around(:each) block
        # results in the error being raised to rspec and the tests failing

        it 'does not create a new DraftTransaction record' do
          expect do
            subject.in_new_draft_transaction do
              subject.ensure_in_draft_transaction do
                raise(ActiveRecord::Rollback, "Error to force a rollback")
              end
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'rolls back the transaction if an error is raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              subject.ensure_in_draft_transaction do
                create_dummy_record!(dummy_record_name)
                raise(ActiveRecord::Rollback, "Error to force a rollback")
              end
            end
          end.not_to change { dummy_record_count(dummy_record_name) }
        end
      end
    end

    context 'when a draft transaction exists in another thread' do
      around(:each) do |example|
        other_thread = Fiber.new do
          subject.in_new_draft_transaction do
            # Wait inside the transaction until other_thread.resume is called
            Fiber.yield
          end
        end

        other_thread.resume # run other_thread up to Fiber.yield...
        example.run
        other_thread.resume # wake up other_thread so it can complete...
      end

      it 'creates a DraftTransaction record' do
        expect do
          subject.ensure_in_draft_transaction { true }
        end.to change { DraftTransaction.count }.by(1)
      end

      it 'executes the code in the block successfully' do
        expect do
          subject.ensure_in_draft_transaction do
            create_dummy_record!(dummy_record_name)
          end
        end.to change { dummy_record_count(dummy_record_name) }.by(1)
      end
    end
  end

  describe '.current_draft_transaction!' do
    let(:correct_draft_transaction_user) { 'correct DraftTransaction user' }
    let(:other_draft_transaction_user)   { 'some other DraftTransaction user' }

    context 'when no existing draft transaction' do
      it 'throws NoDraftTransactionError' do
        expect do
          subject.current_draft_transaction!
        end.to raise_error(DraftApprove::NoDraftTransactionError)
      end
    end

    context 'when a draft transaction already exists in this thread' do
      around(:each) do |example|
        subject.in_new_draft_transaction(created_by: correct_draft_transaction_user) do
          example.run
        end
      end

      it 'returns the correct draft transaction' do
        draft_transaction = subject.current_draft_transaction!
        expect(draft_transaction.created_by).to eq(correct_draft_transaction_user)
      end
    end

    context 'when a draft transaction exists in another thread' do
      around(:each) do |example|
        other_thread = Fiber.new do
          subject.in_new_draft_transaction(created_by: other_draft_transaction_user) do
            # Wait inside the transaction until other_thread.resume is called
            Fiber.yield
          end
        end

        other_thread.resume # run other_thread up to Fiber.yield...
        example.run
        other_thread.resume # wake up other_thread so it can complete...
      end

      it 'throws NoDraftTransactionError' do
        expect do
          subject.current_draft_transaction!
        end.to raise_error(DraftApprove::NoDraftTransactionError)
      end
    end

    context 'when a draft transaction exists in this thread and another thread' do
      around(:each) do |example|
        other_thread = Fiber.new do
          subject.in_new_draft_transaction(created_by: other_draft_transaction_user) do
            # Wait inside the transaction until other_thread.resume is called
            Fiber.yield
          end
        end

        other_thread.resume # run other_thread up to Fiber.yield...
        subject.in_new_draft_transaction(created_by: correct_draft_transaction_user) do
          example.run
        end
        other_thread.resume # wake up other_thread so it can complete...
      end

      it 'returns the correct draft transaction' do
        draft_transaction = subject.current_draft_transaction!
        expect(draft_transaction.created_by).to eq(correct_draft_transaction_user)
      end
    end
  end
end

# What executes within the transaction blocks in the tests is largely
# irrelevant. We just need something which persists outside the transaction
# blocks so we can check outside the transaction whether the data was committed
# or rolled back as executed. We arbitrarily use the roles table for this...
def create_dummy_record!(record_name)
  Role.create!(name: record_name)
end

def dummy_record_count(record_name)
  Role.where(name: record_name).count
end
