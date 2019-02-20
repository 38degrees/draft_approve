class DraftTransaction < ActiveRecord::Base
  # IMPORTANT NOTE: These constants are written to the database, so cannot be
  # updated without requiring a migration of existing draft data
  PENDING_APPROVAL = 'pending_approval'.freeze
  APPROVED = 'approved'.freeze
  REJECTED = 'rejected'.freeze
  APPROVAL_ERROR = 'approval_error'.freeze

  has_many :drafts

  validates :status, inclusion: {
    in: [PENDING_APPROVAL, APPROVED, REJECTED, APPROVAL_ERROR],
    message: "%{value} is not a valid DraftTransaction.status"
  }

  scope :pending_approval, -> { where(status: PENDING_APPROVAL) }
  scope :approved, -> { where(status: APPROVED) }
  scope :rejected, -> { where(status: REJECTED) }
  scope :approval_error, -> { where(status: APPROVAL_ERROR) }

  def approve_changes!(reviewed_by: nil, review_reason: nil)
    # TODO: Don't approve changes if already approved/rejected
    
    begin
      ActiveRecord::Base.transaction do
        drafts.order(:created_at, :id).each do |draft|
          draft.apply_changes!
        end
      end
    rescue StandardError => e
      # Log the error in the database table and re-raise
      self.update!(status: APPROVAL_ERROR, error: "#{e.inspect}\n#{e.backtrace.join("\n")}")
      raise
    end

    self.update!(status: APPROVED, reviewed_by: reviewed_by, review_reason: review_reason)
    return true
  end

  def reject_changes!(reviewed_by: nil, review_reason: nil)
    self.update!(status: REJECTED, reviewed_by: reviewed_by, review_reason: review_reason)
  end
end
