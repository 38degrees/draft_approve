require 'draft_approve/draftable/class_methods'
require 'draft_approve/draftable/instance_methods'
require 'draft_approve/models/draft'

module DraftApprove
  module Draftable
    module BaseClassMethods
      def has_drafts(options={})
        include DraftApprove::Draftable::InstanceMethods
        extend DraftApprove::Draftable::ClassMethods

        has_one :draft, as: :draftable
      end
    end
  end
end
