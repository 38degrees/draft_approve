require 'spec_helper'

RSpec.describe 'Draft Approve Scenario Tests', integration: true do
  context 'when not using an explicit Draft Approve Transaction' do
    let(:role_name) { 'integration test role name' }

    context 'when creating a new record' do
      it 'creates the new record when the draft transaction is approved' do
        # Declare draft so we have reference to it outside the first expect block
        draft = nil

        # Create the draft
        expect do
          draft = Role.new(name: role_name).draft_save!
        end.to change { Draft.count }.by(1).and change { DraftTransaction.count }.by(1)

        # Approve the draft
        expect do
          draft.draft_transaction.approve_changes!
        end.to change { Role.count }.by(1)

        expect(Role.where(name: role_name).count).to eq(1)
      end
    end

    context 'when updating an existing record' do
      let!(:model) { FactoryBot.create(:role) }

      it 'updates the record when the draft transaction is approved' do
        # Declare draft so we have reference to it outside the first expect block
        draft = nil

        # Create the draft
        expect do
          model.name = role_name
          draft = model.draft_save!
        end.to change { Draft.count }.by(1).and change { DraftTransaction.count }.by(1)

        # Approve the draft
        expect do
          draft.draft_transaction.approve_changes!
        end.not_to change { Role.count }

        expect(model.reload.name).to eq(role_name)
      end
    end

    context 'when deleting an existing record' do
      let!(:model) { FactoryBot.create(:role) }

      it 'deletes the record when the draft transaction is approved' do
        # Declare draft so we have reference to it outside the first expect block
        draft = nil

        # Create the draft
        expect do
          draft = model.draft_destroy!
        end.to change { Draft.count }.by(1).and change { DraftTransaction.count }.by(1)

        # Approve the draft
        expect do
          draft.draft_transaction.approve_changes!
        end.to change { Role.count }.by(-1)

        expect(Role.where(name: role_name).count).to eq(0)
      end
    end
  end

  context 'when using an explicit Draft Approve Transaction' do
    let(:gender_name)          { 'integration test gender name' }
    let(:person_name)          { 'integration test person name' }
    let(:person_birthday)      { DateTime.now }
    let(:organization_name)    { 'integration test org name' }
    let(:role_name)            { 'integration test role name' }
    let(:membership_start)     { Time.now }
    let(:contact_type_name)    { 'integration test contact type name' }
    let(:person_contact_label) { nil }
    let(:person_contact_value) { 'integration test person contact value' }
    let(:org_contact_label)    { 'integration test org contact label' }
    let(:org_contact_value)    { 'integration test org contact value' }
    let(:member_contact_label) { nil }
    let(:member_contact_value) { 'integration test membership contact value' }

    context 'when creating multiple linked new records' do
      # Setup unpersisted records with links between them
      let!(:gender) { Gender.new(name: gender_name) }
      let!(:person) { Person.new(name: person_name, gender: gender, birth_date: person_birthday) }
      let!(:org) { Organization.new(name: organization_name) }
      let!(:role) { Role.new(name: role_name) }
      let!(:membership) { Membership.new(person: person, organization: org, role: role, start_date: membership_start) }
      let!(:contact_type) { ContactAddressType.new(name: contact_type_name) }
      let!(:person_contact) { ContactAddress.new(contact_address_type: contact_type, contactable: person, label: person_contact_label, value: person_contact_value) }
      let!(:org_contact) { ContactAddress.new(contact_address_type: contact_type, contactable: org, label: org_contact_label, value: org_contact_value) }
      let!(:member_contact) { ContactAddress.new(contact_address_type: contact_type, contactable: membership, label: member_contact_label, value: member_contact_value) }

      it 'creates all new records when the draft transaction is approved' do
        # Declare transaction so we have reference to it outside the first expect block
        draft_transaction = nil

        # Save drafts of all the unpersisted records, to create a complex chain of drafts in the correct order
        expect do
          draft_transaction = Gender.draft_transaction do
            gender.draft_save!
            person.draft_save!
            org.draft_save!
            role.draft_save!
            membership.draft_save!
            contact_type.draft_save!
            person_contact.draft_save!
            org_contact.draft_save!
            member_contact.draft_save!
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(9)

        # Approve the draft
        expect do
          draft_transaction.approve_changes!
        end.to change { Gender.count }.by(1)
        .and change { Person.count }.by(1)
        .and change { Organization.count }.by(1)
        .and change { Role.count }.by(1)
        .and change { Membership.count }.by(1)
        .and change { ContactAddressType.count }.by(1)
        .and change { ContactAddress.count }.by(3)
      end
    end

    context 'when updating multiple existing linked records' do
      # Setup existing dummy records to be updated
      let!(:gender) { FactoryBot.create(:gender) }
      let!(:person) { FactoryBot.create(:person) }
      let!(:org) { FactoryBot.create(:organization) }
      let!(:role) { FactoryBot.create(:role) }
      let!(:membership) { FactoryBot.create(:membership) }
      let!(:contact_type) { FactoryBot.create(:contact_address_type) }
      let!(:person_contact) { FactoryBot.create(:contact_address) }
      let!(:org_contact) { FactoryBot.create(:contact_address) }
      let!(:member_contact) { FactoryBot.create(:contact_address) }

      it 'updates all records when the draft transaction is approved' do
        # Declare transaction so we have reference to it outside the first expect block
        draft_transaction = nil

        # Update each model and save each draft
        # (order doesn't matter here since every record is already persisted)
        expect do
          draft_transaction = Membership.draft_transaction do
            person_contact.contact_address_type = contact_type
            person_contact.contactable = person
            person_contact.label = person_contact_label
            person_contact.value = person_contact_value
            person_contact.draft_save!

            org_contact.contact_address_type = contact_type
            org_contact.contactable = org
            org_contact.label = org_contact_label
            org_contact.value = org_contact_value
            org_contact.draft_save!

            member_contact.contact_address_type = contact_type
            member_contact.contactable = membership
            member_contact.label = member_contact_label
            member_contact.value = member_contact_value
            member_contact.draft_save!

            membership.person = person
            membership.organization = org
            membership.role = role
            membership.start_date = membership_start
            membership.draft_save!

            contact_type.name = contact_type_name
            contact_type.draft_save!

            person.name = person_name
            person.gender = gender
            person.birth_date = person_birthday
            person.draft_save!

            org.name = organization_name
            org.draft_save!

            role.name = role_name
            role.draft_save!

            gender.name = gender_name
            gender.draft_save!
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(9)

        # Approve the draft
        expect do
          draft_transaction.approve_changes!
        end.to change { Gender.count }.by(0)
        .and change { Person.count }.by(0)
        .and change { Organization.count }.by(0)
        .and change { Role.count }.by(0)
        .and change { Membership.count }.by(0)
        .and change { ContactAddressType.count }.by(0)
        .and change { ContactAddress.count }.by(0)

        # Force relaod of all variables from database now we've approved changes
        [gender, person, org, role, membership, contact_type, person_contact, org_contact, member_contact].each do |record|
          record.reload
        end

        # Ensure all records are updated with all changes
        expect(gender.name).to eq(gender_name)

        expect(person.name).to eq(person_name)
        expect(person.gender).to eq(gender)
        expect(person.birth_date).to be_within(0.5.seconds).of(person_birthday)

        expect(org.name).to eq(organization_name)

        expect(role.name).to eq(role_name)

        expect(membership.person).to eq(person)
        expect(membership.organization).to eq(org)
        expect(membership.role).to eq(role)
        expect(membership.start_date).to be_within(0.5.seconds).of(membership_start)

        expect(contact_type.name).to eq(contact_type_name)

        expect(person_contact.contact_address_type).to eq(contact_type)
        expect(person_contact.contactable).to eq(person)
        expect(person_contact.label).to eq(person_contact_label)
        expect(person_contact.value).to eq(person_contact_value)

        expect(org_contact.contact_address_type).to eq(contact_type)
        expect(org_contact.contactable).to eq(org)
        expect(org_contact.label).to eq(org_contact_label)
        expect(org_contact.value).to eq(org_contact_value)

        expect(member_contact.contact_address_type).to eq(contact_type)
        expect(member_contact.contactable).to eq(membership)
        expect(member_contact.label).to eq(member_contact_label)
        expect(member_contact.value).to eq(member_contact_value)
      end
    end

    context 'when deleting multiple existing linked records' do
      # Setup existing records with links between them
      let!(:gender) { Gender.create!(name: gender_name) }
      let!(:person) { Person.create!(name: person_name, gender: gender, birth_date: person_birthday) }
      let!(:org) { Organization.create!(name: organization_name) }
      let!(:role) { Role.create!(name: role_name) }
      let!(:membership) { Membership.create!(person: person, organization: org, role: role, start_date: membership_start) }
      let!(:contact_type) { ContactAddressType.create!(name: contact_type_name) }
      let!(:person_contact) { ContactAddress.create!(contact_address_type: contact_type, contactable: person, label: person_contact_label, value: person_contact_value) }
      let!(:org_contact) { ContactAddress.create!(contact_address_type: contact_type, contactable: org, label: org_contact_label, value: org_contact_value) }
      let!(:member_contact) { ContactAddress.create!(contact_address_type: contact_type, contactable: membership, label: member_contact_label, value: member_contact_value) }

      it 'deletes all records when the draft transaction is approved' do
        # Declare transaction so we have reference to it outside the first expect block
        draft_transaction = nil

        # Draft deletion of each model in a sensible order
        expect do
          draft_transaction = ContactAddress.draft_transaction do
            person_contact.draft_destroy!
            org_contact.draft_destroy!
            member_contact.draft_destroy!
            contact_type.draft_destroy!
            membership.draft_destroy!
            role.draft_destroy!
            org.draft_destroy!
            person.draft_destroy!
            gender.draft_destroy!
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(9)

        # Approve the draft
        expect do
          draft_transaction.approve_changes!
        end.to change { Gender.count }.by(-1)
        .and change { Person.count }.by(-1)
        .and change { Organization.count }.by(-1)
        .and change { Role.count }.by(-1)
        .and change { Membership.count }.by(-1)
        .and change { ContactAddressType.count }.by(-1)
        .and change { ContactAddress.count }.by(-3)
      end
    end

    context 'when creating, updating and deleting records within the same transaction' do
      # Setup existing records with links between them
      let!(:gender) { Gender.create!(name: gender_name) }
      let!(:person) { Person.create!(name: person_name, gender: gender, birth_date: person_birthday) }
      let!(:org) { Organization.create!(name: organization_name) }
      let!(:role) { Role.create!(name: role_name) }
      let!(:membership) { Membership.create!(person: person, organization: org, role: role, start_date: membership_start) }
      let!(:contact_type) { ContactAddressType.create!(name: contact_type_name) }
      let!(:person_contact) { ContactAddress.create!(contact_address_type: contact_type, contactable: person, label: person_contact_label, value: person_contact_value) }
      let!(:org_contact) { ContactAddress.create!(contact_address_type: contact_type, contactable: org, label: org_contact_label, value: org_contact_value) }
      let!(:member_contact) { ContactAddress.create!(contact_address_type: contact_type, contactable: membership, label: member_contact_label, value: member_contact_value) }

      let(:new_role_name)            { 'integration test role name NEW' }
      let(:new_org_name)             { 'integration test org name NEW' }
      let(:new_contact_type_name)    { 'integration test contact type name NEW' }
      let(:new_person_contact_label) { 'integration test org contact label NEW' }
      let(:new_person_contact_value) { 'integration test org contact value NEW' }

      it 'creates / updates / deletes all records correctly when the draft transaction is approved' do
        # Declare transaction so we have reference to it outside the first expect block
        draft_transaction = nil

        # Draft changes of each model in a sensible order, using various convenience methods to create drafts
        expect do
          draft_transaction = Person.draft_transaction do
            Person.find_and_draft_update_or_create_draft_by!(name: person_name) do |person|
              person.gender = nil
            end

            gender.draft_destroy!

            new_role_draft = Role.draft_create!(name: new_role_name)

            new_org_draft = Organization.draft_create!(name: new_org_name)

            membership.draft_update!(role: new_role_draft.draftable, organization: new_org_draft.draftable)

            org_contact.draft_update!(contactable: new_org_draft.draftable)

            org.draft_destroy!

            new_contact_type = ContactAddressType.find_and_draft_update_or_create_draft_by!(
              name: new_contact_type_name
            )

            new_person_contact = ContactAddress.find_and_draft_update_or_create_draft_by!(
              contact_address_type: new_contact_type,
              contactable: person,
              value: new_person_contact_value
            ) do |contact_address|
              contact_address.label = new_person_contact_label
            end

            person_contact.draft_destroy!
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(10)

        # Approve the draft
        expect do
          draft_transaction.approve_changes!
        end.to change { Gender.count }.by(-1)           # 1 destroyed
        .and change { Person.count }.by(0)              # 1 updated
        .and change { Organization.count }.by(0)        # 1 created, 1 destroyed
        .and change { Role.count }.by(1)                # 1 created
        .and change { Membership.count }.by(0)          # 1 updated
        .and change { ContactAddressType.count }.by(1)  # 1 created
        .and change { ContactAddress.count }.by(0)      # 1 updated, 1 created, 1 destroyed

        # Force reload now that changes have been approved
        [person, membership, org_contact].each do |model|
          model.reload
        end

        expect(person.gender).to be(nil)

        expect(Gender.where(name: gender).count).to eq(0)

        expect(Role.where(name: new_role_name).count).to eq(1)
        new_role = Role.find_by(name: new_role_name)

        expect(Organization.where(name: new_org_name).count).to eq(1)
        new_org = Organization.find_by(name: new_org_name)

        expect(membership.person).to eq(person)
        expect(membership.organization).to eq(new_org)
        expect(membership.role).to eq(new_role)

        expect(org_contact.contactable).to eq(new_org)

        expect(Organization.where(name: organization_name).count).to eq(0)

        expect(ContactAddressType.where(name: new_contact_type_name).count).to eq(1)
        new_contact_type = ContactAddressType.find_by(name: new_contact_type_name)

        expect(person.contact_addresses.size).to eq(1)
        expect(person.contact_addresses.first.contact_address_type).to eq(new_contact_type)
        expect(person.contact_addresses.first.label).to eq(new_person_contact_label)
        expect(person.contact_addresses.first.value).to eq(new_person_contact_value)
      end
    end

    context 'when some no-op drafts are saved' do
      # Want to check that updated_at doesn't change, but the database loses
      # granularity and tests run quickly! So set the updated_at far enough in
      # the past to make up for the loss in granularity.
      let!(:create_time) { Time.now - 10.seconds }
      let!(:db_time_tolerance) { 0.5.seconds }

      # Setup existing records with links between them
      let!(:gender) { Gender.create!(name: gender_name, created_at: create_time, updated_at: create_time) }
      let!(:person) { Person.create!(name: person_name, gender: gender, created_at: create_time, updated_at: create_time) }
      let!(:org) { Organization.create!(name: organization_name, created_at: create_time, updated_at: create_time) }
      let!(:role) { Role.create!(name: role_name, created_at: create_time, updated_at: create_time) }
      let!(:membership) { Membership.create!(person: person, organization: org, role: role, start_date: membership_start, created_at: create_time, updated_at: create_time) }

      let(:person_birthday_new) { DateTime.now }

      let(:role_updated_at_new) { Time.now }

      it 'does not persist no-op drafts, and does not modify records with no-op drafts' do
        # Declare transaction so we have reference to it outside the first expect block
        draft_transaction = nil

        # Draft updates
        expect do
          draft_transaction = Person.draft_transaction do
            # no-op draft for gender
            gender.name = gender_name
            gender.draft_save!

            # real change for person
            person.draft_update!(birth_date: person_birthday_new)

            # no-op change for organization
            org.draft_update!(name: organization_name)

            # real change for role
            role.updated_at = role_updated_at_new
            role.draft_save!

            # real delete for membership
            membership.draft_destroy!
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(3)

        # Approve the draft
        expect do
          draft_transaction.approve_changes!
        end.to change { Gender.count }.by(0)     # 1 no-op
        .and change { Person.count }.by(0)       # 1 updated
        .and change { Organization.count }.by(0) # 1 no-op
        .and change { Role.count }.by(0)         # 1 updated
        .and change { Membership.count }.by(-1)  # 1 destroyed

        # Check that no-op changes did not modify the updated_at
        expect(gender.reload.updated_at).to be_within(db_time_tolerance).of(create_time)
        expect(org.reload.updated_at).to be_within(db_time_tolerance).of(create_time)
      end
    end

    context 'when only no-op drafts are saved' do
      # Setup existing records with links between them
      let!(:gender) { Gender.create!(name: gender_name) }
      let!(:person) { Person.create!(name: person_name, gender: gender) }
      let!(:org) { Organization.create!(name: organization_name) }
      let!(:role) { Role.create!(name: role_name) }
      let!(:membership) { Membership.create!(person: person, organization: org, role: role, start_date: membership_start) }

      it 'does not persist any drafts, and does not persist a draft transaction' do
        # Declare transaction so we have reference to it outside the first expect block
        draft_transaction = nil

        # Draft updates
        expect do
          draft_transaction = Person.draft_transaction do
            # no-op draft for gender
            gender.name = gender_name
            gender.draft_save!

            # no-op change for person
            person.draft_update!(birth_date: nil)

            # no-op change for organization
            org.draft_update!(name: organization_name)

            # no-op change for role
            role.draft_save!

            # no-op change for membership
            membership.person = person
            membership.organization = org
            membership.role = role
            membership.draft_save!
          end
        end.to change { DraftTransaction.count }.by(0).and change { Draft.count }.by(0)

        # Returned draft transaction should also be nil
        expect(draft_transaction).to be(nil)
      end
    end

    context 'when multiple transactions create the same record with create_method create!' do
      let(:new_role_name) { 'integration test role name NEW' }

      it 'creates the new record when the first transaction is approved, and the second transaction raises an error' do
        # Declare transactions so we have reference to them outside the expect blocks
        draft_transaction_1, draft_transaction_2 = nil

        # Draft create the new role, using find_or_create_by
        expect do
          draft_transaction_1 = Role.draft_transaction do
            new_role = Role.new(name: new_role_name)
            new_role.draft_save!(create_method: :create!)
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(1)

        # Draft create the new role again
        expect do
          draft_transaction_2 = Role.draft_transaction do
            new_role = Role.new(name: new_role_name)
            new_role.draft_save!(create_method: :create!)
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(1)

        # Approve the first draft
        expect do
          draft_transaction_1.approve_changes!
        end.to change { Role.count }.by(1)

        draft_1_role = draft_transaction_1.drafts.first.draftable
        expect(draft_1_role.class).to eq(Role)
        expect(draft_1_role.name).to eq(new_role_name)

        # Approve the second draft, which should raise an error
        expect do
          draft_transaction_2.approve_changes!
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context 'when multiple transactions create the same record with create_method find_or_create_by!' do
      let(:new_role_name) { 'integration test role name NEW' }

      it 'creates the new record once only, and both drafts end up pointing to the same draftable record' do
        # Declare transactions so we have reference to them outside the expect blocks
        draft_transaction_1, draft_transaction_2 = nil

        # Draft create the new role, using find_or_create_by
        expect do
          draft_transaction_1 = Role.draft_transaction do
            new_role = Role.new(name: new_role_name)
            new_role.draft_save!(create_method: :find_or_create_by!)
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(1)

        # Draft create the new role again
        expect do
          draft_transaction_2 = Role.draft_transaction do
            new_role = Role.new(name: new_role_name)
            new_role.draft_save!(create_method: :find_or_create_by!)
          end
        end.to change { DraftTransaction.count }.by(1).and change { Draft.count }.by(1)

        # Approve the first draft
        expect do
          draft_transaction_1.approve_changes!
        end.to change { Role.count }.by(1)

        # Approve the second draft
        expect do
          draft_transaction_2.approve_changes!
        end.not_to change { Role.count }

        # Check both drafts refer to the SAME role object
        draft_1_role = draft_transaction_1.drafts.first.draftable
        draft_2_role = draft_transaction_2.drafts.first.draftable

        expect(draft_1_role.class).to eq(Role)
        expect(draft_2_role.class).to eq(Role)

        expect(draft_1_role.name).to eq(new_role_name)
        expect(draft_2_role.name).to eq(new_role_name)

        expect(draft_1_role.id).to eq(draft_2_role.id)
      end
    end
  end
end
