class Draft < ActiveRecord::Base
  belongs_to :draft_transaction
  belongs_to :draftable, polymorphic: true, optional: true

  validates :action_type, inclusion: {
    in: [DraftApprove::CREATE, DraftApprove::UPDATE, DraftApprove::DELETE],
    message: "%{value} is not a valid Draft.action_type"
  }

  # Approve changes, writing the draft changes to the database
  def approve_changes
    apply_changes

    case action_type
    when DraftApprove::CREATE, DraftApprove::UPDATE
      save!
    when DraftApprove::DELETE
      destroy!
    else
      raise(ArgumentError, "Unknown action_type #{action_type}")
    end
  end

  # Applies changes IN MEMORY only (ie. does not write anything to the database)
  def apply_changes
    case action_type
    when DraftApprove::CREATE
      raise(DraftApprove::NoDraftableError, "No draftable_type for #{draft}") if draftable_type.blank?

      Object.const_get(draftable_type).find_or_initialize_by(new_values_hash)
    when DraftApprove::UPDATE
      raise(DraftApprove::NoDraftableError, "No draftable for #{draft}") if draftable.blank?

      new_values_hash.each do |attribute_name, new_value|
        self.public_send("#{attribute_name}=", new_value)
      end
    when DraftApprove::DELETE
      raise(DraftApprove::NoDraftableError, "No draftable for #{draft}") if draftable.blank?
      # We don't apply any changes, since the record is being deleted...
    else
      raise(ArgumentError, "Unknown action_type #{action_type}")
    end
  end

  private

  def new_values_hash
    association_attribute_names = model.class.reflect_on_all_associations(:belongs_to).map(&:name).map(&:to_s)

    return changes.each_with_object({}) do |(attribute_name, change), result_hash|
      new_value = change[1]
      if association_attribute_names.include?(attribute_name)
        result_hash[attribute_name] = associated_model_for_new_value(new_value)
      else
        result_hash[attribute_name] = new_value
      end
    end
  end

  def associated_model_for_new_value(new_value)
    associated_model_type = new_value[DraftApprove::TYPE]
    associated_model_id = new_value[DraftApprove::ID]

    if associated_model_type == Draft.class
      draft = draft_transaction.drafts.select { |draft| draft.id == associated_model_id }
      raise(PriorDraftsNotAppliedError) if draft.nil? || draft.draftable.nil?
      return draft.draftable
    else
      return Object.const_get(associated_model_type).find(associated_model_id)
    end
  end
end
