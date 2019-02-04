class Draft < ActiveRecord::Base
  # IMPORTANT NOTE: These constants are written to the database, so cannot be
  # updated without requiring a (potentially very slow) migration of all
  # existing draft data
  CREATE = 'create'.freeze
  UPDATE = 'update'.freeze
  DELETE = 'delete'.freeze

  belongs_to :draft_transaction
  belongs_to :draftable, polymorphic: true, optional: true

  validates :action_type, inclusion: {
    in: [CREATE, UPDATE, DELETE],
    message: "%{value} is not a valid Draft.action_type"
  }

  # Approve changes, writing the draft changes to the database
  def approve_changes
    DraftApprove::Persistor.write_model_from_draft(self)
  end
end
