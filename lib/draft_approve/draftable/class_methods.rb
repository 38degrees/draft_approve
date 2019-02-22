require 'draft_approve/transaction'

module DraftApprove
  module Draftable

    # Class methods automatically added to an ActiveRecord model when
    # +acts_as_draftable+ is called
    module ClassMethods
      ##### Basic DraftApprove class methods #####

      # Starts a new +DraftTransaction+ to group together a number of draft
      # changes that must be approved and applied together.
      #
      # @yield the block which creates a group of draft changes that must be
      #   approved and applied together
      # @param created_by [String] the person or process responsible for
      #   creating the draft changes in this transaction
      # @param extra_data [Hash] any extra metadata to be associated with
      #   these draft changes
      #
      # @return [DraftTransaction, nil] the +DraftTransaction+ which was
      #   created, or +nil+ if no draft changes were saved within the given
      #   block (ie. if approving the +DraftTransaction+ would be a
      #   'no-operation')
      def draft_transaction(created_by: nil, extra_data: nil)
        DraftApprove::Transaction.in_new_draft_transaction(created_by: created_by, extra_data: extra_data) do
          yield
        end
      end

      ##### Additional convenience DraftApprove class methods #####

      # Creates a new object with the given attributes, and saves the new object
      # as a draft.
      #
      # @param attributes [Hash] a hash of attribute names to attribute values,
      #   like the hash expected by the ActiveRecord +create+ / +create!+
      #   methods
      #
      # @return [Draft] the resulting +Draft+ record (*not* the created
      #   draftable object)
      def draft_create!(attributes)
        self.new(attributes).draft_save!
      end

      # Finds an object with the given attributes. If none found, creates a new
      # object with the given attributes, executes the given block, and saves
      # the new object as a draft.
      #
      # @param attributes [Hash] a hash of attribute names to attribute values,
      #   like the hash expected by the ActiveRecord +find_or_create_by+ method
      # @yield [instance] a block which sets additional attributes on the newly
      #   created object instance if no existing instance is found
      #
      # @return [Object] the draftable object which was found or created
      #   (*not* the +Draft+ object which may have been saved)
      #
      # @example
      #   # Find a person by their name. If no person found, create a person
      #   # with that name, and also set their birth date.
      #   Person.find_or_create_draft_by!(name: 'My Name') do |p|
      #     p.birth_date = '1980-01-01'
      #   end
      def find_or_create_draft_by!(attributes)
        instance = self.find_by(attributes)

        if instance.blank?
          instance = self.new(attributes)

          # Only execute the block if this is a new record
          yield(instance) if block_given?
        end

        instance.draft_save!
        return instance
      end

      # Finds an object with the given attributes and draft update it with the
      # given block, or draft create a new object.
      #
      # If an object is found matching the given attributes, the given block
      # is applied to this object and the updates are saved as a draft.
      #
      # If no object is found matching the given attributes, a new object is
      # initialised with the given attributes, and the given block is applied to
      # this new object before it is saved as a draft.
      #
      # @param attributes [Hash] a hash of attribute names to attribute values,
      #   like the hash expected by the ActiveRecord +find_or_create_by+ method
      # @yield [instance] a block which makes changes to the object instance
      #   which was found or created using the given attributes hash
      #
      # @return [Object] the draftable object which was found and updated, or
      #   the draftable object which was created (*not* the +Draft+ object
      #   which may have been saved)
      #
      # @example
      #   # Find a person by their name, and draft update their birth date,
      #   # OR draft create a person with the given name and birth date.
      #   Person.find_and_draft_update_or_create_draft_by!(name: 'My Name') do |p|
      #     p.birth_date = '1980-01-01'
      #   end
      def find_and_draft_update_or_create_draft_by!(attributes)
        instance = self.find_by(attributes)

        if instance.blank?
          instance = self.new(attributes)
        end

        # Whether or not this is a new record, execute the block to update
        # additional, non-find_by attributes
        yield(instance) if block_given?

        instance.draft_save!
        return instance
      end
    end
  end
end
