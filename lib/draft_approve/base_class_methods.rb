module DraftApprove
  module BaseClassMethods
    def has_drafts(options={})
      include DraftApprove::InstanceMethods
      extend DraftApprove::ClassMethods

      has_one :draft, as: :draftable
    end
  end
end
