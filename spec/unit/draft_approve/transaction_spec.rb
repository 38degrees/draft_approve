require 'spec_helper'

RSpec.describe DraftApprove::Transaction do
  let(:subject) { DraftApprove::Transaction }
  let(:dummy_record_name) { 'some_dummy_record' }

  describe '.in_new_draft_transaction' do
    context 'when no existing draft transaction' do
      context 'when no error occurs in the given block' do
        it 'creates a DraftTransaction record' do
          expect do
            subject.in_new_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
            end
          end.to change { DraftTransaction.count }.by(1)
        end

        it 'returns a DraftTransaction with the correct status' do
          draft_transaction = subject.in_new_draft_transaction do
            create_dummy_draft_record!(dummy_record_name)
          end
          expect(draft_transaction.status).to eq(DraftTransaction::PENDING_APPROVAL)
        end

        it 'executes the code in the block successfully' do
          expect do
            subject.in_new_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
            end
          end.to change { dummy_draft_record_count(dummy_record_name) }.by(1)
        end

        context 'when a created_by is passed in' do
          let(:created_by) { 'A test user' }

          it 'returns a DraftTransaction with the correct created_by' do
            draft_transaction = subject.in_new_draft_transaction(created_by: created_by) do
              create_dummy_draft_record!(dummy_record_name)
            end
            expect(draft_transaction.created_by).to eq(created_by)
          end

          it 'persists the DraftTransaction with the correct created_by' do
            draft_transaction = subject.in_new_draft_transaction(created_by: created_by) do
              create_dummy_draft_record!(dummy_record_name)
            end
            expect(draft_transaction.reload.created_by).to eq(created_by)
          end
        end

        context 'when extra_data is passed in' do
          let(:extra_data) { { 'foo' => 'bar' } }

          it 'returns a DraftTransaction with the correct extra_data' do
            draft_transaction = subject.in_new_draft_transaction(extra_data: extra_data) do
              create_dummy_draft_record!(dummy_record_name)
            end
            expect(draft_transaction.extra_data).to eq(extra_data)
          end

          it 'persists the DraftTransaction with the correct extra_data' do
            draft_transaction = subject.in_new_draft_transaction(extra_data: extra_data) do
              create_dummy_draft_record!(dummy_record_name)
            end
            expect(draft_transaction.reload.extra_data).to eq(extra_data)
          end
        end
      end

      context 'when no drafts are created in the given block' do
        let(:role_name) { 'Test Role Name' }

        it 'does not create a DraftTransaction record' do
          expect do
            subject.in_new_draft_transaction do
              Role.create!(name: role_name)
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'persists any non-draft changes within the block' do
          expect do
            subject.in_new_draft_transaction do
              Role.create!(name: role_name)
            end
          end.to change { Role.where(name: role_name).count }.by(1)
        end

        it 'returns nil' do
          return_value = subject.in_new_draft_transaction do
            Role.create!(name: role_name)
          end

          expect(return_value).to be(nil)
        end
      end

      context 'when an error occurs in the given block' do
        it 'does not create a DraftTransaction record if an error is raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              raise(ActiveRecord::Rollback, "Force rollback, but don't re-raise")
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'rolls back the transaction if an error is raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
              raise(ActiveRecord::Rollback, "Force rollback, but don't re-raise")
            end
          end.not_to change { dummy_draft_record_count(dummy_record_name) }
        end

        it 're-raises the exception raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
              raise(NoMethodError, "Force rollback and re-raise")
            end
          end.to raise_error(NoMethodError)
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
          subject.in_new_draft_transaction do
            create_dummy_draft_record!(dummy_record_name)
          end
        end.to change { DraftTransaction.count }.by(1)
      end

      it 'returns a DraftTransaction with the correct status' do
        draft_transaction = subject.in_new_draft_transaction do
          create_dummy_draft_record!(dummy_record_name)
        end
        expect(draft_transaction.status).to eq(DraftTransaction::PENDING_APPROVAL)
      end

      it 'executes the code in the block successfully' do
        expect do
          subject.in_new_draft_transaction do
            create_dummy_draft_record!(dummy_record_name)
          end
        end.to change { dummy_draft_record_count(dummy_record_name) }.by(1)
      end
    end
  end

  describe '.ensure_in_draft_transaction' do
    context 'when no existing draft transaction' do
      context 'when no error occurs in the given block' do
        it 'creates a DraftTransaction record' do
          expect do
            subject.in_new_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
            end
          end.to change { DraftTransaction.count }.by(1)
        end

        it 'returns the value of the given block' do
          return_value = subject.ensure_in_draft_transaction do
            create_dummy_draft_record!(dummy_record_name)
          end

          expect(return_value.class).to eq(Draft)
          expect(return_value.draftable_type).to eq(dummy_record_class.name)
        end

        it 'executes the code in the block successfully' do
          expect do
            subject.ensure_in_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
            end
          end.to change { dummy_draft_record_count(dummy_record_name) }.by(1)
        end
      end

      context 'when no drafts are created in the given block' do
        let(:role_name) { 'Test Role Name' }

        it 'does not create a DraftTransaction record' do
          expect do
            subject.ensure_in_draft_transaction do
              Role.create!(name: role_name)
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'persists any non-draft changes within the block' do
          expect do
            subject.ensure_in_draft_transaction do
              Role.create!(name: role_name)
            end
          end.to change { Role.where(name: role_name).count }.by(1)
        end

        it 'returns the value of the given block' do
          return_value = subject.ensure_in_draft_transaction do
            Role.create!(name: role_name)
          end

          expect(return_value.class).to eq(Role)
          expect(return_value.name).to eq(role_name)
        end
      end

      context 'when an error occurs in the given block' do
        it 'does not create a DraftTransaction record if an error is raised in the block' do
          expect do
            subject.ensure_in_draft_transaction do
              raise(ActiveRecord::Rollback, "Force rollback, but don't re-raise")
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'rolls back the transaction if an error is raised in the block' do
          expect do
            subject.ensure_in_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
              raise(ActiveRecord::Rollback, "Force rollback, but don't re-raise")
            end
          end.not_to change { dummy_draft_record_count(dummy_record_name) }
        end

        it 're-raises the exception raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
              raise(NoMethodError, "Force rollback and re-raise")
            end
          end.to raise_error(NoMethodError)
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
            subject.ensure_in_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'executes the code in the block successfully' do
          expect do
            subject.ensure_in_draft_transaction do
              create_dummy_draft_record!(dummy_record_name)
            end
          end.to change { dummy_draft_record_count(dummy_record_name) }.by(1)
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
                raise(ActiveRecord::Rollback, "Force rollback, but don't re-raise")
              end
            end
          end.not_to change { DraftTransaction.count }
        end

        it 'rolls back the transaction if an error is raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              subject.ensure_in_draft_transaction do
                create_dummy_draft_record!(dummy_record_name)
                raise(ActiveRecord::Rollback, "Force rollback, but don't re-raise")
              end
            end
          end.not_to change { dummy_draft_record_count(dummy_record_name) }
        end

        it 're-raises the exception raised in the block' do
          expect do
            subject.in_new_draft_transaction do
              subject.ensure_in_draft_transaction do
                create_dummy_draft_record!(dummy_record_name)
                raise(NoMethodError, "Force rollback and re-raise")
              end
            end
          end.to raise_error(NoMethodError)
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
          subject.in_new_draft_transaction do
            create_dummy_draft_record!(dummy_record_name)
          end
        end.to change { DraftTransaction.count }.by(1)
      end

      it 'executes the code in the block successfully' do
        expect do
          subject.ensure_in_draft_transaction do
            create_dummy_draft_record!(dummy_record_name)
          end
        end.to change { dummy_draft_record_count(dummy_record_name) }.by(1)
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
def dummy_record_class
  Role
end

def create_dummy_draft_record!(record_name)
  dummy_record_class.new(name: record_name).save_draft!
end

def dummy_draft_record_count(record_name)
  Draft.where(draftable_type: dummy_record_class.name, draft_changes: { 'name' => [nil, record_name] }).count
end
