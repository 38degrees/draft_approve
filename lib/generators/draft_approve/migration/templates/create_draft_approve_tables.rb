class CreateDraftApproveTables < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :draft_transactions, comment: 'Table linking multiple drafts to be applied in sequence, within a transaction' do |t|
      t.string :user, comment: 'The user or process which created this transaction'

      t.timestamps
    end

    create_table :drafts, comment: 'Drafts of changes to be approved' do |t|
      t.references        :draft_transaction, null: false, index: true, foreign_key: true
      t.references        :draftable,         null: true,  index: true, polymorphic: true
      t.string            :action_type,       null: false
      t.<%= json_type %>  :draft_changes,     null: false
      t.<%= json_type %>  :draft_options,     null: true

      t.timestamps
    end
  end
end
