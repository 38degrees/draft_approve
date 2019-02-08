# Define global traits, which are useful for using on draftable objects

FactoryBot.define do
  trait :with_persisted_draft do
    after(:build) do |model, evaluator|
      # We always pass nil as the draftable here, since otherwise FactoryBot
      # may write the draftable to the database, when we don't always want
      # that behaviour...
      draft = FactoryBot.create(:draft, draftable: nil)

      # Once the Draft instantiated, manually setup the references between the
      # draftable object and the draft object
      draft.draftable = model
      model.draft_pending_approval = draft
    end
  end

  trait :with_unpersisted_draft do
    after(:build) do |model, evaluator|
      # We always pass nil as the draftable here, since otherwise FactoryBot
      # may write the draftable to the database, when we don't always want
      # that behaviour...
      draft = FactoryBot.build(:draft, draftable: nil)

      # Once the Draft instantiated, manually setup the references between the
      # draftable object and the draft object
      draft.draftable = model
      model.draft_pending_approval = draft
    end
  end
end
