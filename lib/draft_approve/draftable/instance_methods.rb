require 'draft_approve/persistor'

module DraftApprove
  module Draftable
    module InstanceMethods
      ##### Basic DraftApprove instance methods #####

      # Whether this object is draftable. Helper method to identify draftable
      # objects.
      #
      # @return [Boolean] true
      def draftable?
        true
      end

      # Saves any changes to the object as a draft.
      #
      # This method may be called both on a new object which has not been
      # persisted yet, and on objects which have already been persisted.
      #
      # @param options [Hash] the options to save the draft with
      # @option options [Symbol] :create_method the method to use when creating
      #   a new object from this draft, eg. `:find_or_create_by!`. This must be
      #   a method available on the object, and must accept a hash of attribute
      #   names to attribute values. The default is `create!`. Ignored if this
      #   draft is for an object which has already been persisted.
      # @option options [Symbol] :update_method the method to use when updating
      #   an existing object from this draft, eg. `:update_columns`. This must
      #   be a method available on the object, and must accept a hash of
      #   attribute names to attribute values. The default is `update!`. Ignored
      #   if this draft is for an object which has not yet been persisted.
      #
      # @return [Draft, nil] the `Draft` object which was created, or `nil` if
      #   there were no changes to the object
      def draft_save!(options = nil)
        if self.new_record?
          DraftApprove::Persistor.write_draft_from_model(Draft::CREATE, self, options)
        else
          DraftApprove::Persistor.write_draft_from_model(Draft::UPDATE, self, options)
        end
      end

      # Marks this object to be destroyed when this draft change is approved.
      #
      # This method should only be called on objects which have already been
      # persisted.
      #
      # @param options [Hash] the options to save the draft with
      # @option options [Symbol] :delete_method the method to use to delete
      #   the object when this draft is approved, eg. `:delete`. This must be
      #   a method available on the object. The default is `destroy!`.
      #
      # @return [Draft] the `Draft` object which was created
      def draft_destroy!(options = nil)
        DraftApprove::Persistor.write_draft_from_model(Draft::DELETE, self, options)
      end

      ##### Additional convenience DraftApprove instance methods #####

      # Updates an existing object with the given attributes, and saves the
      # updates as a draft.
      #
      # @param attributes [Hash] a hash of attribute names to attribute values,
      #   like the hash expected by the ActiveRecord `update` / `update!`
      #   methods
      #
      # @return [Draft, nil] the `Draft` object which was created, or `nil` if
      #   there were no changes to the object
      def draft_update!(attributes)
        self.assign_attributes(attributes)
        self.draft_save!
      end
    end
  end
end
