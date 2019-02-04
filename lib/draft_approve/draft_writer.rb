require 'draft_approve/constants'
require 'draft_approve/errors'
require 'draft_approve/models/draft'
require 'draft_approve/serializers/json'

module DraftApprove
  #TODO: Rename this to 'DraftPersistor' or something, and shift the 'draft#apply_changes' method in here?
  class DraftWriter
    # This method just ensures save_draft_type_helper is wrapped in a DraftTransaction
    def self.save_draft(action_type, model)
      DraftApprove::DraftApproveTransaction.ensure_in_draft_transaction do
        save_draft_helper(action_type, model)
      end
    end

    private

    def self.save_draft_helper(action_type, model)
      raise(ArgumentError, 'model argument must be present') unless model.present?

      # Now we're in a Transaction, reload the model to force going back to the
      # DB, to ensure we don't get multiple drafts for the same object
      if model.persisted? && model.reload.draft.present?
        raise(DraftApprove::ExistingDraftError, "#{model} has existing draft")
      end

      draft_transaction = DraftApprove::DraftApproveTransaction.current_draft_transaction!

      case action_type
      when DraftApprove::CREATE
        raise(DraftApprove::AlreadyPersistedModelError, "#{model} is already persisted") if model.persisted?
        model.draft = Draft.create!(
          draft_transaction: draft_transaction,
          draftable_type: model.class,
          draftable_id: nil,
          action_type: DraftApprove::CREATE,
          draft_changes: serializer.changes_for_model(model)
        )
      when DraftApprove::UPDATE
        raise(DraftApprove::UnpersistedModelError, "#{model} isn't persisted") unless model.persisted?
        model.draft = Draft.create!(
          draft_transaction: draft_transaction,
          draftable: model,
          action_type: DraftApprove::UPDATE,
          draft_changes: serializer.changes_for_model(model)
        )
      when DraftApprove::DELETE
        raise(DraftApprove::UnpersistedModelError, "#{model} isn't persisted") unless model.persisted?
        model.draft = Draft.create!(
          draft_transaction: draft_transaction,
          draftable: model,
          action_type: DraftApprove::DELETE,
          draft_changes: serializer.changes_for_model(model)
        )
      else
        raise(ArgumentError, "Unknown action_type #{action_type}")
      end

      return model.draft
    end

    def self.serializer
      # TODO: Factor this out into a config setting or something...
      DraftApprove::Serializers::Json
    end
  end
end
