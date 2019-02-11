require 'draft_approve/persistor'

module DraftApprove
  module Draftable
    module InstanceMethods
      ##### Basic DraftApprove instance methods #####

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

      ##### Additional convenience DraftApprove instance methods #####

      # Expects an attributes hash, like the ActiveRecord update / update! methods
      # Returns the resulting draft
      def draft_update!(attributes)
        self.assign_attributes(attributes)
        self.save_draft!
      end
    end
  end
end
