FactoryBot.define do
  factory :draft do
    association   :draft_transaction
    association   :draftable, factory: :person
    action_type   { Draft::UPDATE }
    draft_changes { {} }
    draft_options { {} }
  end

  trait :skip_validations do
    to_create {|instance| instance.save(validate: false)}
  end
end
