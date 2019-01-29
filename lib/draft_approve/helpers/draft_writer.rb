require 'draft_approve/errors'
require 'draft_approve/models/draft'

module DraftApprove
  module Helpers
    class DraftWriter
      # This method just ensures save_draft_type_helper is wrapped in a DraftTransaction
      def self.save_draft(action_type, model)
        DraftApprove::Helpers::DraftApproveTransaction.ensure_in_draft_transaction do
          save_draft_helper(action_type, model_to_save)
        end
      end

      private

      def self.save_draft_helper(action_type, model)
        # Now we're in a Transaction, reload the drafts association to force going
        # back to the DB, to ensure we don't get multiple drafts for the same object
        raise(DraftApprove::ExistingDraftError, "#{model} has existing draft") if draft.reload.present?

        case action_type
        when DraftApprove::Draft::CREATE
          raise(DraftApprove::AlreadyPersistedModelError, "#{model} is already persisted") unless model.new_record?
          DraftApprove::Draft.create!(
            draft_transaction: draft_transaction,
            draftable: nil,
            action_type: DraftApprove::Draft::CREATE,
            changes: changes_for_model(model)
          )
        when DraftApprove::Draft::UPDATE
          raise(DraftApprove::UnpersistedModelError, "#{model} isn't persisted") if model.new_record?
          DraftApprove::Draft.create!(
            draft_transaction: draft_transaction,
            draftable: model,
            action_type: DraftApprove::Draft::UPDATE,
            changes: changes_for_model(model)
          )
        when DraftApprove::Draft::DELETE
          raise(DraftApprove::UnpersistedModelError, "#{model} isn't persisted") if model.new_record?
          DraftApprove::Draft.create!(
            draft_transaction: draft_transaction,
            draftable: model,
            action_type: DraftApprove::Draft::DELETE,
            changes: changes_for_model(model)
          )
        else
          raise(DraftApprove::UnknownDraftActionError, "Unknown action_type #{action_type}")
        end
      end

      def self.changes_for_model(model)
        changes = {}

        model.class.reflect_on_all_associations(:belongs_to).each do |belongs_to_assoc|
          if belongs_to_assoc.polymorphic?
            changes.merge(polymorphic_association_changes(model, belongs_to_assoc))
          else
            changes.merge(non_polymorphic_association_changes(model, belongs_to_assoc))
          end
        end

        changes.merge(non_association_changes(model))

        return changes
      end

      def self.polymorphic_association_changes(model, association)
        changes = {}
        association_method_name = association.name
        associated_obj = model.public_send(association_method_name)
        foreign_type_column_name = association.foreign_type
        foreign_key_column_name = association.foreign_key

        if associated_obj.present? && associated_obj.new_record?
          # The associated object is an unsaved record

          unless associated_obj.draft.present? && associated_obj.draft.persisted?
            raise "Can't save draft which references #{associated_obj} - associated object isn't saved & doesn't have a persisted draft"
          end

          changes[foreign_type_column_name] = model.public_send("#{foreign_type_column_name}_change")
          changes[foreign_key_column_name] = [
            model.public_send("#{foreign_key_column_name}_was"),
            { 'draft_id' => associated_obj.draft.id }
          ]
        else
          # The associated object either references nothing, or references a saved record
          changes[foreign_type_column_name] = model.public_send("#{foreign_type_column_name}_change")
          changes[foreign_key_column_name] = model.public_send("#{foreign_key_column_name}_change")
        end

        return changes
      end

      def self.non_polymorphic_association_changes(model, association)
        changes = {}
        association_method_name = association.name
        associated_obj = model.public_send(association_method_name)
        foreign_key_column_name = association.association_foreign_key

        if associated_obj.present? && associated_obj.new_record?
          # The associated object is an unsaved record

          unless associated_obj.draft.present? && associated_obj.draft.persisted?
            raise "Can't save draft which references #{associated_obj} - associated object isn't saved & doesn't have a persisted draft"
          end

          changes[foreign_key_column_name] = [
            model.public_send("#{foreign_key_column_name}_was"),
            { 'draft_id' => associated_obj.draft.id }
          ]
        else
          # The associated object either references nothing, or references a saved record
          changes[foreign_key_column_name] = model.public_send("#{foreign_key_column_name}_change")
        end

        return changes
      end

      def self.non_association_changes(model)
        changes = {}

        association_attribute_names = model.class.reflect_on_all_associations(:belongs_to).map do |ref|
          [ref.foreign_type, ref.foreign_key, ref.association_foreign_key]
        end.flatten.uniq.compact

        non_association_attribute_names = model.attribute_names - association_attribute_names

        non_association_attribute_names.each do |attribute_name|
          if model.public_send("#{attribute_name}_changed?")
            changes[attribute_name] = model.public_send("#{attribute_name}_change")
          end
        end

        return changes
      end
    end
  end
end
