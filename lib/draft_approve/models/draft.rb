class Draft < ActiveRecord::Base
  # IMPORTANT NOTE: These constants are written to the database, so cannot be
  # updated without requiring a migration of existing draft data
  CREATE = 'create'.freeze
  UPDATE = 'update'.freeze
  DELETE = 'delete'.freeze

  belongs_to :draft_transaction
  belongs_to :draftable, polymorphic: true, optional: true

  validates :draft_action_type, inclusion: {
    in: [CREATE, UPDATE, DELETE],
    message: "%{value} is not a valid Draft.draft_action_type"
  }

  scope :pending_approval, -> { joins(:draft_transaction).merge(DraftTransaction.pending_approval) }
  scope :approved, -> { joins(:draft_transaction).merge(DraftTransaction.approved) }
  scope :rejected, -> { joins(:draft_transaction).merge(DraftTransaction.rejected) }
  scope :approval_error, -> { joins(:draft_transaction).merge(DraftTransaction.approval_error) }

  # Approve changes, writing the draft changes to the database
  def apply_changes!
    DraftApprove::Persistor.write_model_from_draft(self)
  end
end
