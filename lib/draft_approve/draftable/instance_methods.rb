require 'draft_approve/persistor'

module DraftApprove
  module Draftable
    module InstanceMethods

      def save_draft!(options = nil)
        if self.new_record?
          DraftApprove::Persistor.write_draft_from_model(Draft::CREATE, self, options)
        else
          DraftApprove::Persistor.write_draft_from_model(Draft::UPDATE, self, options)
        end
      end

      def draft_destroy!(options = nil)
        DraftApprove::Persistor.write_draft_from_model(Draft::DELETE, self, options)
      end
    end
  end
end
