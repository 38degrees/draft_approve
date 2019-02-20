# Define global traits, which are useful for using on draftable objects

FactoryBot.define do
  trait :with_persisted_draft do
    transient do
      draft_transaction { FactoryBot.create(:draft_transaction) }
      draft_action_type { Draft::UPDATE }
      draft_changes     { {} }
    end

    after(:build) do |model, evaluator|
      # We always pass nil as the draftable here, since otherwise FactoryBot
      # may write the draftable to the database, when we don't always want
      # that behaviour... We explicitly set the draftable_type and draftable_id
      # though, so these are always available as they should be.
      draft = FactoryBot.create(
        :draft,
        draftable: nil,
        draftable_type: model.class.name,
        draftable_id: model.id,
        draft_transaction: evaluator.draft_transaction,
        draft_action_type: evaluator.draft_action_type,
        draft_changes: evaluator.draft_changes
      )

      # Once the Draft instantiated, manually setup the references between the
      # draftable object and the draft object
      draft.draftable = model
      model.draft_pending_approval = draft
    end
  end

  trait :with_unpersisted_draft do
    transient do
      draft_transaction { FactoryBot.create(:draft_transaction) }
      draft_action_type { Draft::UPDATE }
      draft_changes     { {} }
    end

    after(:build) do |model, evaluator|
      # We always pass nil as the draftable here, since otherwise FactoryBot
      # may write the draftable to the database, when we don't always want
      # that behaviour... We explicitly set the draftable_type and draftable_id
      # though, so these are always available as they should be.
      draft = FactoryBot.build(
        :draft,
        draftable: nil,
        draftable_type: model.class.name,
        draftable_id: model.id,
        draft_transaction: evaluator.draft_transaction,
        draft_action_type: evaluator.draft_action_type,
        draft_changes: evaluator.draft_changes
      )

      # Once the Draft instantiated, manually setup the references between the
      # draftable object and the draft object
      draft.draftable = model
      model.draft_pending_approval = draft
    end
  end
end
