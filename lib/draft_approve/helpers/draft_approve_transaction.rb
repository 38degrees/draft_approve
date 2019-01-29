require 'draft_approve/errors'
require 'draft_approve/models/draft_transaction'

module DraftApprove
  module Helpers
    class DraftApproveTransaction
      # Start a new database Transaction, and create a new DraftTransaction to
      # wrap the commands in the block
      def self.in_new_draft_transaction(user: nil)
        raise DraftApprove::NestedDraftTransactionError if current_draft_transaction.present?

        ActiveRecord::Base.transaction do
          begin
            self.current_draft_transaction = DraftApprove::DraftTransaction.create!(user: user)
            yield
          ensure
            self.current_draft_transaction = nil
          end
        end
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
          in_new_draft_transaction(user: user) do
            yield
          end
        end
      end

      # Get the current Draft Transaction, or raise an error
      def self.current_draft_transaction!
        raise DraftApprove::NoDraftTransactionError unless current_draft_transaction.present?

        current_draft_transaction
      end

      private

      def self.current_draft_transaction
        Thread.current[:draft_approve_transaction]
      end

      def self.current_draft_transaction=(draft_transaction)
        Thread.current[:draft_approve_transaction] = draft_transaction
      end
    end
  end
end
