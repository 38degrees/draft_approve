require 'draft_approve/transaction'

module DraftApprove
  module Draftable
    module ClassMethods
      ##### Basic DraftApprove class methods #####

      # Start a new DraftTransaction to group together all the draft changes
      # which must be approved and applied together
      def draft_transaction(created_by: nil, extra_data: nil)
        DraftApprove::Transaction.in_new_draft_transaction(created_by: created_by, extra_data: extra_data) do
          yield
        end
      end

      ##### Additional convenience DraftApprove class methods #####

      # Expects an attributes hash, like the ActiveRecord create / create! methods
      # Returns the resulting draft
      def draft_create!(attributes)
        self.new(attributes).draft_save!
      end

      # Expects an attributes hash to find an instance or create a draft
      # instance, and expects a block which will always execute on the instance,
      # ie. the block will either update the existing instance and create a
      # new draft for the instance, or update the newly created draft instance
      # before it is saved.
      #
      # Returns the instance of the object (NOT the draft).
      #
      # For example, the following will look for a Person with name 'My Name'.
      # If the person already existed, it will create a draft update to update
      # their birth date. If the person does not exist, it will create a draft
      # to create the person, setting their name and birth date.
      #
      # Person.find_and_draft_update_or_create_draft_by!(name: 'My Name') do |p|
      #   p.birth_date = '1980-01-01'
      # end
      def find_and_draft_update_or_create_draft_by!(attributes)
        instance = self.find_by(attributes)

        if instance.blank?
          instance = self.new(attributes)
        end

        if block_given?
          yield(instance)
        end

        instance.draft_save!

        return instance
      end
    end
  end
end
