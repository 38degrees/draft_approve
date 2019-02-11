require 'draft_approve/errors'
require 'draft_approve/models/draft_transaction'

module DraftApprove
  class Transaction
    # Start a new database Transaction, and create a new DraftTransaction to
    # wrap the commands in the block
    def self.in_new_draft_transaction(created_by: nil, extra_data: nil)
      (draft_transaction, yield_return) = in_new_draft_transaction_helper(created_by: created_by, extra_data: extra_data) do
        yield
      end

      # in_new_draft_transaction is used in Model.draft_transaction do ... blocks
      # so we want to return the transaction itself to the caller
      return draft_transaction
    end

    # Ensure the block is running in a DraftTransaction - if there's not one
    # already, create one
    def self.ensure_in_draft_transaction(created_by: nil, extra_data: nil)
      draft_transaction = current_draft_transaction

      if draft_transaction
        # There's an existing draft_transaction, just yield to the block
        yield
      else
        # There's no transaction - start one and yield to the block inside the
        # new transaction
        (draft_transaction, yield_return) = in_new_draft_transaction_helper(created_by: created_by, extra_data: extra_data) do
          yield
        end

        # ensure_in_draft_transaction is used in model.save_draft! method calls
        # so we want to return the result of the yield (a draft object) to the caller
        return yield_return
      end
    end

    # Get the current Draft Transaction, or raise an error
    def self.current_draft_transaction!
      raise DraftApprove::NoDraftTransactionError unless current_draft_transaction.present?

      current_draft_transaction
    end

    private

    def self.in_new_draft_transaction_helper(created_by: nil, extra_data: nil)
      raise DraftApprove::NestedDraftTransactionError if current_draft_transaction.present?
      draft_transaction, yield_return = nil

      ActiveRecord::Base.transaction do
        begin
          draft_transaction = DraftTransaction.create!(
            status: DraftTransaction::PENDING_APPROVAL,
            created_by: created_by,
            extra_data: extra_data
          )
          self.current_draft_transaction = draft_transaction
          yield_return = yield

          # If no drafts exist at this point, this is a no-op Draft Transaction,
          # so no point storing it - destroy it.
          # NOTE: We don't rollback the transaction here, because non-draft
          # changes may have occurred inside the yield block!
          if draft_transaction.drafts.empty?
            draft_transaction.destroy!
            draft_transaction = nil
          end
        ensure
          self.current_draft_transaction = nil
        end
      end

      return draft_transaction, yield_return
    end

    def self.current_draft_transaction
      Thread.current[:draft_approve_transaction]
    end

    def self.current_draft_transaction=(draft_transaction)
      Thread.current[:draft_approve_transaction] = draft_transaction
    end
  end
end
