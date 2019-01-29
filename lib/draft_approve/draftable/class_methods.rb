require 'draft_approve/helpers/draft_approve_transaction'

module DraftApprove
  module Draftable
    module ClassMethods

      # draft_transaction starts a new DraftApproveTransaction to group together
      # all draft changes which must be approved and applied together
      def draft_transaction(user: nil)
        DraftApprove::Helpers::DraftApproveTransaction.in_new_draft_transaction(user) do
          yield
        end
      end
    end
  end
end
