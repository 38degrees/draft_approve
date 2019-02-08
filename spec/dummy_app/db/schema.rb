ActiveRecord::Schema.define do

  create_table "contact_address_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_contact_types_on_name", unique: true
  end

  create_table "contact_addresses", force: :cascade do |t|
    t.bigint "contact_address_type_id", null: false
    t.string "contactable_type", null: false
    t.bigint "contactable_id", null: false
    t.string "label"
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_type_id"], name: "index_contact_addresses_on_contact_address_type_id"
    t.index ["contactable_type", "contactable_id"], name: "index_contact_addresses_on_contactable"
  end

  create_table "genders", force: :cascade do |t|
    t.string "name", null: false
    t.string "commonly_used_title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_genders_on_name", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "role_id"
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["end_date"], name: "index_memberships_on_end_date"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["person_id"], name: "index_memberships_on_person_id"
    t.index ["role_id"], name: "index_memberships_on_role_id"
    t.index ["start_date"], name: "index_memberships_on_start_date"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organizations_on_name"
  end

  create_table "people", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "gender_id"
    t.datetime "birth_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["birth_date"], name: "index_people_on_birth_date"
    t.index ["gender_id"], name: "index_people_on_gender_id"
    t.index ["name"], name: "index_people_on_name"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  add_foreign_key "contact_addresses", "contact_address_types"

  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "people"
  add_foreign_key "memberships", "roles"

  add_foreign_key "people", "genders"

  # TODO: The below creates the tables required by draft_approve. Ideally these
  # should not be in the dummy_app schema, but we should instead generate and
  # run the draft_approve migration(s) as part of the test suite setup. Worry
  # about this later though...

  create_table :draft_transactions, comment: 'Table linking multiple drafts to be applied in sequence, within a transaction' do |t|
    t.string :status,        null: false, index: true,  comment: 'The status of the drafts within this transaction (pending approval, approved, rejected, errored)'
    t.string :created_by,    null: true,  index: true,  comment: 'The user or process which created the drafts in this transaction'
    t.string :reviewed_by,   null: true,  index: true,  comment: 'The user who approved or rejected the drafts in this transaction'
    t.string :review_reason, null: true,  index: false, comment: 'The reason given by the user for approving or rejecting the drafts in this transaction'
    t.string :error,         null: true,  index: false, comment: 'If there was an error while approving this transaction, more information on the error that occurred'

    t.timestamps
  end

  create_table :drafts, comment: 'Drafts of changes to be approved' do |t|
    t.references :draft_transaction, null: false, index: true, foreign_key: true
    t.references :draftable,         null: true,  index: true, polymorphic: true
    t.string     :draft_action_type, null: false
    t.string     :draft_serializer,  null: false
    t.json       :draft_changes,     null: false
    t.json       :draft_options,     null: true

    t.timestamps
  end
end
