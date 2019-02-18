class CreateDraftApproveTables < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :draft_transactions, comment: 'Table linking multiple drafts to be applied in sequence, within a transaction' do |t|
      t.string            :status,        null: false, index: true,  comment: 'The status of the drafts within this transaction (pending approval, approved, rejected, errored)'
      t.string            :created_by,    null: true,  index: true,  comment: 'The user or process which created the drafts in this transaction'
      t.string            :reviewed_by,   null: true,  index: true,  comment: 'The user who approved or rejected the drafts in this transaction'
      t.string            :review_reason, null: true,  index: false, comment: 'The reason given by the user for approving or rejecting the drafts in this transaction'
      t.string            :error,         null: true,  index: false, comment: 'If there was an error while approving this transaction, more information on the error that occurred'
      t.<%= json_type %>  :extra_data,    null: true,  index: false, comment: 'Any extra data associated with this draft transaction, eg. users / roles who are authorised to approve the changes'

      t.timestamps
    end

    create_table :drafts, comment: 'Drafts of changes to be approved' do |t|
      t.references        :draft_transaction,   null: false, index: true, foreign_key: true
      t.references        :draftable,           null: true,  index: true, polymorphic: true
      t.string            :draft_action_type,   null: false
      t.string            :draft_serialization, null: false
      t.<%= json_type %>  :draft_changes,       null: false
      t.<%= json_type %>  :draft_options,       null: true

      t.timestamps
    end
  end
end
