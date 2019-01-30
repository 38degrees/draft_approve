require 'draft_approve/constants'
require 'draft_approve/draft_writer'

module DraftApprove
  module Draftable
    module InstanceMethods

      def save_draft!
        if self.new_record?
          DraftApprove::DraftWriter.save_draft(DraftApprove::CREATE)
        else
          DraftApprove::DraftWriter.save_draft(DraftApprove::UPDATE)
        end
      end

      def draft_destroy!
        DraftApprove::DraftWriter.save_draft(DraftApprove::DELETE)
      end
    end
  end
end
