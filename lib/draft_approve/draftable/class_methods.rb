require 'draft_approve/transaction'

module DraftApprove
  module Draftable
    module ClassMethods

      # Start a new DraftTransaction to group together all the draft changes
      # which must be approved and applied together
      def draft_transaction(created_by: nil)
        DraftApprove::Transaction.in_new_draft_transaction(created_by: created_by) do
          yield
        end
      end
    end
  end
end
