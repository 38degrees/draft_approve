require 'draft_approve/draftable/class_methods'
require 'draft_approve/draftable/instance_methods'
require 'draft_approve/models/draft'

module DraftApprove
  module Draftable

    # Methods automatically added to +ActiveRecord::Base+ when including the
    # DraftApprove gem
    module BaseClassMethods

      # Allows the object to be used as a draftable, adding the
      # +DraftApprove::Draftable+ instance and class methods to the object.
      #
      # @param options [Hash] optional configuration, currently unused
      #
      # @example
      #   class Person < ActiveRecord::Base
      #     acts_as_draftable
      #   end
      #
      # @see DraftApprove::Draftable::InstanceMethods
      # @see DraftApprove::Draftable::ClassMethods
      def acts_as_draftable(options={})
        include DraftApprove::Draftable::InstanceMethods
        extend DraftApprove::Draftable::ClassMethods

        has_many :drafts, as: :draftable
        has_one :draft_pending_approval, -> { pending_approval }, class_name: "Draft", as: :draftable, inverse_of: :draftable
      end
    end
  end
end
