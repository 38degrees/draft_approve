require 'draft_approve/errors'
require 'draft_approve/models/draft'
require 'draft_approve/serializers/json'

module DraftApprove
  class Persistor
    # IMPORTANT NOTE: These constants are written to the database, so cannot be
    # updated without requiring a (potentially very slow) migration of all
    # existing draft data
    SERIALIZER_CLASS = 'serializer_class'.freeze

    def self.write_draft_from_model(action_type, model)
      DraftApprove::Transaction.ensure_in_draft_transaction do
        raise(ArgumentError, 'model argument must be present') unless model.present?

        # Now we're in a Transaction, ensure we don't get multiple drafts for the same object
        if model.persisted? && Draft.where(draftable: model).count > 0
          raise(DraftApprove::ExistingDraftError, "#{model} has existing draft")
        end

        draft_transaction = DraftApprove::Transaction.current_draft_transaction!

        case action_type
        when Draft::CREATE
          raise(DraftApprove::AlreadyPersistedModelError, "#{model} is already persisted") if model.persisted?
          draftable_type = model.class
          draftable_id = nil
        when Draft::UPDATE
          raise(DraftApprove::UnpersistedModelError, "#{model} isn't persisted") unless model.persisted?
          draftable_type = model.class
          draftable_id = model.id
        when Draft::DELETE
          raise(DraftApprove::UnpersistedModelError, "#{model} isn't persisted") unless model.persisted?
          draftable_type = model.class
          draftable_id = model.id
        else
          raise(ArgumentError, "Unknown action_type #{action_type}")
        end

        model.draft = Draft.create!(
          draft_transaction: draft_transaction,
          draftable_type: draftable_type,
          draftable_id: draftable_id,
          action_type: action_type,
          draft_changes: serializer_class.changes_for_model(model),
          draft_options: { SERIALIZER_CLASS => serializer_class.name }
        )
      end
    end

    def self.write_model_from_draft(draft)
      if serializer_class_name = draft.draft_options[SERIALIZER_CLASS]
        serializer = Object.const_get(serializer_class_name)
      else
        serializer = serializer_class # Use default serializer
      end
      new_values_hash = serializer.new_values_for_draft(draft)

      case draft.action_type
      when Draft::CREATE
        raise(DraftApprove::NoDraftableError, "No draftable_type for #{draft}") if draft.draftable_type.blank?

        model_class = Object.const_get(draft.draftable_type)
        return model_class.create!(new_values_hash) # TODO: allow options for specifying method here (eg. find_or_create_by!)
      when Draft::UPDATE
        raise(DraftApprove::NoDraftableError, "No draftable for #{draft}") if draft.draftable.blank?

        model = draft.draftable
        model.update!(new_values_hash)
        return model
      when Draft::DELETE
        raise(DraftApprove::NoDraftableError, "No draftable for #{draft}") if draft.draftable.blank?

        model = draft.draftable
        model.destroy!
        return model
      else
        raise(ArgumentError, "Unknown action_type #{draft.action_type}")
      end
    end

    private

    def self.serializer_class
      # TODO: Factor this out into a config setting or something...
      DraftApprove::Serializers::Json
    end
  end
end
