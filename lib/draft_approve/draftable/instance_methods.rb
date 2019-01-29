require 'draft_approve/helpers/draft_writer'

module DraftApprove
  module Draftable
    module InstanceMethods

      def save_draft!
        if self.new_record?
          DraftApprove::Helpers::DraftWriter.save_draft(DraftApprove::Draft::CREATE)
        else
          DraftApprove::Helpers::DraftWriter.save_draft(DraftApprove::Draft::UPDATE)
        end
      end

      def draft_destroy!
        DraftApprove::Helpers::DraftWriter.save_draft(DraftApprove::Draft::DELETE)
      end
    end
  end
end
