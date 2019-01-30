require 'draft_approve/draft_writer'

module DraftApprove
  module Draftable
    module InstanceMethods

      def save_draft!
        if self.new_record?
          DraftApprove::DraftWriter.save_draft(DraftApprove::Draft::CREATE)
        else
          DraftApprove::DraftWriter.save_draft(DraftApprove::Draft::UPDATE)
        end
      end

      def draft_destroy!
        DraftApprove::DraftWriter.save_draft(DraftApprove::Draft::DELETE)
      end
    end
  end
end
