require 'draft_approve/errors'
require 'draft_approve/models/draft_transaction'

module DraftApprove
  class Transaction
    # Start a new database Transaction, and create a new DraftTransaction to
    # wrap the commands in the block
    def self.in_new_draft_transaction(user: nil)
      (draft_transaction, yield_return) = in_new_draft_transaction_helper(user: user) do
        yield
      end

      # in_new_draft_transaction is used in Model.draft_transaction do ... blocks
      # so we want to return the transaction itself to the caller
      return draft_transaction
    end

    # Ensure the block is running in a DraftTransaction - if there's not one
    # already, create one
    def self.ensure_in_draft_transaction(user: nil)
      draft_transaction = current_draft_transaction

      if draft_transaction
        # There's an existing draft_transaction, just yield to the block
        yield
      else
        # There's no transaction - start one and yield to the block inside the
        # new transaction
        (draft_transaction, yield_return) = in_new_draft_transaction_helper(user: user) do
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

    def self.in_new_draft_transaction_helper(user: nil)
      raise DraftApprove::NestedDraftTransactionError if current_draft_transaction.present?
      draft_transaction, yield_return = nil

      ActiveRecord::Base.transaction do
        begin
          draft_transaction = DraftTransaction.create!(user: user)
          self.current_draft_transaction = draft_transaction
          yield_return = yield
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
