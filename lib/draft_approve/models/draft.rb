# @note It is strongly recommended that you do not directly create +Draft+
#   objects, and instead use the supported public interface for doing so. See
#   +DraftApprove::Draftable::ClassMethods+,
#   +DraftApprove::Draftable::InstanceMethods+, and the README docs for this.
#
# ActiveRecord model for persisting data about draft changes.
#
# Each +Draft+ must be linked to a +DraftTransaction+, and must have a
# +draft_action_type+ which specifies whether this draft is to create a new
# record, update a record, or delete a record.
#
# If the draft is to update or delete an existing record in the database, the
# +Draft+ will also have a link to the +acts_as_draftable+ instance to which it
# relates, via the polymorphic +draftable+ association.
#
# Linking to the +acts_as_draftable+ instance is not possible for drafts which
# create new records, since the new record does not yet exist in the database!
# In these cases, the +draftable_type+ column is still set to the name of the
# class which is to be created, but the +draftable_id+ is +nil+.
#
# The +draft_changes+ attribute is a serialized representation of the draft
# changes. The representation is delegated to a +DraftApprove::Serialization+
# module. At present, there is only a JSON implementation, suitable for use with
# PostgreSQL databases.
#
# Note that saving 'no-op' +Draft+s is generally avoided by this library
# (specifically by the +DraftApprove::Persistor+ class).
#
# @see DraftTransaction
# @see DraftApprove::Draftable::ClassMethods
# @see DraftApprove::Draftable::InstanceMethods
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
