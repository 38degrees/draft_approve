# @note It is strongly recommended that you do not directly create
#   +DraftTransaction+ objects, and instead use the supported public interface
#   for doing so. See +DraftApprove::Draftable::ClassMethods+ and the README
#   docs for this.
#
# ActiveRecord model for persisting data about a group of draft changes which
# should be approved or rejected as a single, transactional group.
#
# Each +DraftTransaction+ has many linked +Draft+ objects.
#
# When a +DraftTransaction+ is first created, it has +status+ of
# +pending_approval+. The changes should then be reviewed and either approved or
# rejected.
#
# +DraftTransaction+ objects also have optional attribute for storing who or
# what created the transaction and the group of draft changes (+created_by+
# attribute), who or what reviewed the changes (+reviewed_by+ attribute), and
# the reason given for approving or rejecting the changes (+review_reason+
# attribute), and finally the stack trace of any error which occurred during
# the process of applying the changes (+error+ attribute).
#
# Arbitrary extra data can also be stored in the +extra_data+ attribute.
#
# Note that saving 'no-op' +DraftTransaction+s is generally avoided by this
# library (specifically by the +DraftApprove::Transaction+ class).
#
# @see Draft
# @see DraftApprove::Draftable::ClassMethods
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

  # Approve all changes in this +DraftTransaction+ and immediately apply them
  # to the database.
  #
  # Note that applying the changes occurs within a database transaction.
  #
  # @param reviewed_by [String] the user or process which approved these changes
  # @param review_reason [String] the reason for approving these changes
  #
  # @return [Boolean] +true+ if the changes were successfully applied
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

  # Reject all changes in this +DraftTransaction+.
  #
  # @param reviewed_by [String] the user or process which rejected these changes
  # @param review_reason [String] the reason for rejecting these changes
  #
  # @return [Boolean] +true+ if the changes were successfully rejected
  def reject_changes!(reviewed_by: nil, review_reason: nil)
    self.update!(status: REJECTED, reviewed_by: reviewed_by, review_reason: review_reason)
    return true
  end

  # Get a +DraftChangesProxy+ for the given object in the scope of this
  # +DraftTransaction+.
  #
  # @param object [Object] the +Draft+ or +acts_as_draftable+ object to
  #   create a +DraftChangesProxy+ for
  #
  # @return [DraftChangesProxy] a proxy to get changes drafted to the given
  #   object and related objects, within the scope of this +DraftTransaction+
  def draft_proxy_for(object)
    serialization_module.get_draft_changes_proxy.new(object, self)
  end

  # @return the module used for serialization by this +DraftTransaction+.
  #
  # @api private
  def serialization_module
    Object.const_get(self.serialization)
  end
end
