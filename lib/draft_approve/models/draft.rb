class Draft < ActiveRecord::Base
  belongs_to :draft_transaction
  belongs_to :draftable, polymorphic: true, optional: true

  validates :action_type, inclusion: {
    in: [DraftApprove::CREATE, DraftApprove::UPDATE, DraftApprove::DELETE],
    message: "%{value} is not a valid Draft.action_type"
  }

  # Approve changes, writing the draft changes to the database
  def approve_changes
    new_values_hash = serializer.new_values_for_draft(self)

    case action_type
    when DraftApprove::CREATE
      raise(DraftApprove::NoDraftableError, "No draftable_type for #{draft}") if draftable_type.blank?

      Object.const_get(draftable_type).create!(new_values_hash) # TODO: allow options for specifying method here (eg. find_or_create_by!)

    when DraftApprove::UPDATE
      raise(DraftApprove::NoDraftableError, "No draftable for #{draft}") if draftable.blank?

      draftable.update!(new_values_hash)

    when DraftApprove::DELETE
      raise(DraftApprove::NoDraftableError, "No draftable for #{draft}") if draftable.blank?

      draftable.destroy!

    else
      raise(ArgumentError, "Unknown action_type #{action_type}")
    end
  end

  def serializer
    # TODO: Add a column to the database for this, so changes to old/legacy serializers in the database could be handled!
    DraftApprove::Serializers::Json
  end
end
