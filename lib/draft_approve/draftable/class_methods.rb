require 'draft_approve/transaction'

module DraftApprove
  module Draftable
    module ClassMethods

      # Start a new DraftTransaction to group together all the draft changes
      # which must be approved and applied together
      def draft_transaction(created_by: nil, extra_data: nil)
        DraftApprove::Transaction.in_new_draft_transaction(created_by: created_by, extra_data: extra_data) do
          yield
        end
      end
    end
  end
end
