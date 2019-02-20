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

  # @return [Boolean] +true+ if this +Draft+ is to create a new record, +false+
  #   otherwise
  def create?
    draft_action_type == CREATE
  end

  # @return [Boolean] +true+ if this +Draft+ is to update an existing record,
  #   +false+ otherwise
  def update?
    draft_action_type == UPDATE
  end

  # @return [Boolean] +true+ if this +Draft+ is to delete an existing record,
  #   +false+ otherwise
  def delete?
    draft_action_type == DELETE
  end

  # Apply the changes in this draft, writing them to the database
  # @api private
  def apply_changes!
    DraftApprove::Persistor.write_model_from_draft(self)
  end
end
