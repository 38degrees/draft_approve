require 'draft_approve/draftable/class_methods'
require 'draft_approve/draftable/instance_methods'
require 'draft_approve/models/draft'

module DraftApprove
  module Draftable
    module BaseClassMethods
      def acts_as_draftable(options={})
        include DraftApprove::Draftable::InstanceMethods
        extend DraftApprove::Draftable::ClassMethods

        has_many :drafts, as: :draftable
        has_one :draft_pending_approval, -> { pending_approval }, class_name: "Draft", as: :draftable, inverse_of: :draftable
      end
    end
  end
end
