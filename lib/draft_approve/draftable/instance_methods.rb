require 'draft_approve/persistor'

module DraftApprove
  module Draftable
    module InstanceMethods

      def save_draft!
        if self.new_record?
          DraftApprove::Persistor.write_draft_from_model(Draft::CREATE, self)
        else
          DraftApprove::Persistor.write_draft_from_model(Draft::UPDATE, self)
        end
      end

      def draft_destroy!
        DraftApprove::Persistor.write_draft_from_model(Draft::DELETE, self)
      end
    end
  end
end
