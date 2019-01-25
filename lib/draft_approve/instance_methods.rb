module DraftApprove
  module InstanceMethods

    def save_draft!
      if self.new_record?
        save_draft_type('CREATE')
      else
        save_draft_type('UPDATE')
      end
    end

    def draft_destroy!
      save_draft_type('DELETE')
    end

    private

    # This method just ensures save_draft_type_helper is wrapped in a DraftTransaction
    def save_draft_type(action_type)
      draft_transaction = Thread.current[:draft_approve_transaction]

      if draft_transaction
        # We have an existing draft_transaction - save the draft with the transaction
        save_draft_type_helper(draft_transaction, action_type)
      else
        # We have no transaction - start one, which will set the thread-local
        # draft_approve_transaction variable - then call the helper method
        self.class.draft_transaction do
          draft_transaction = Thread.current[:draft_approve_transaction]
          self.save_draft_type_helper(draft_transaction, action_type)
        end
      end
    end

    def save_draft_type_helper(draft_transaction, action_type)
      # Now we're in a Transaction, reload the drafts association to force going
      # back to the DB, to ensure we don't get multiple drafts for the same object
      raise "Object #{self} already has an outstanding draft" if draft.reload.present?

      case action_type
      when 'CREATE'
        raise "Can't save draft CREATE on object #{self} which is already persisted" unless self.new_record?
        Draft.create!(draft_transaction: draft_transaction, draftable: nil, action_type: 'CREATE', changes: changes_for_draft)
      when 'UPDATE'
        raise "Can't save draft UPDATE on object #{self} which isn't persisted" if self.new_record?
        Draft.create!(draft_transaction: draft_transaction, draftable: self, action_type: 'UPDATE', changes: changes_for_draft)
      when 'DELETE'
        raise "Can't save draft DELETE on object #{self} which isn't persisted" if self.new_record?
        Draft.create!(draft_transaction: draft_transaction, draftable: self, action_type: 'DELETE', changes: changes_for_draft)
      else
        raise "Unknown action_type #{action_type} for Draft"
      end
    end

    def changes_for_draft
      changes = {}

      self.class.reflect_on_all_associations(:belongs_to).each do |belongs_to_assoc|
        if belongs_to_assoc.polymorphic?
          changes.merge(polymorphic_association_changes(belongs_to_assoc))
        else
          changes.merge(non_polymorphic_association_changes(belongs_to_assoc))
        end
      end

      changes.merge(non_association_changes)

      return changes
    end

    def polymorphic_association_changes(association)
      changes = {}
      association_method_name = association.name
      associated_obj = self.public_send(association_method_name)
      foreign_type_column_name = association.foreign_type
      foreign_key_column_name = association.foreign_key

      if associated_obj.present? && associated_obj.new_record?
        # The associated object is an unsaved record

        unless associated_obj.draft.present? && associated_obj.draft.persisted?
          raise "Can't save draft which references #{associated_obj} - associated object isn't saved & doesn't have a persisted draft"
        end

        changes[foreign_type_column_name] = self.public_send("#{foreign_type_column_name}_change")
        changes[foreign_key_column_name] = [
          self.public_send("#{foreign_key_column_name}_was"),
          { 'draft_id' => associated_obj.draft.id }
        ]
      else
        # The associated object either references nothing, or references a saved record
        changes[foreign_type_column_name] = self.public_send("#{foreign_type_column_name}_change")
        changes[foreign_key_column_name] = self.public_send("#{foreign_key_column_name}_change")
      end

      return changes
    end

    def non_polymorphic_association_changes(association)
      changes = {}
      association_method_name = association.name
      associated_obj = self.public_send(association_method_name)
      foreign_key_column_name = association.association_foreign_key

      if associated_obj.present? && associated_obj.new_record?
        # The associated object is an unsaved record

        unless associated_obj.draft.present? && associated_obj.draft.persisted?
          raise "Can't save draft which references #{associated_obj} - associated object isn't saved & doesn't have a persisted draft"
        end

        changes[foreign_key_column_name] = [
          self.public_send("#{foreign_key_column_name}_was"),
          { 'draft_id' => associated_obj.draft.id }
        ]
      else
        # The associated object either references nothing, or references a saved record
        changes[foreign_key_column_name] = self.public_send("#{foreign_key_column_name}_change")
      end

      return changes
    end

    def non_association_changes
      changes = {}

      association_attribute_names = self.class.reflect_on_all_associations(:belongs_to).map do |ref|
        [ref.foreign_type, ref.foreign_key, ref.association_foreign_key]
      end.flatten.uniq.compact

      non_association_attribute_names = self.attribute_names - association_attribute_names

      non_association_attribute_names.each do |attribute_name|
        if self.public_send("#{attribute_name}_changed?")
          changes[attribute_name] = self.public_send("#{attribute_name}_change")
        end
      end

      return changes
    end
  end
end
