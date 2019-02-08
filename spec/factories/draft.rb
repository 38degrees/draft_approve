FactoryBot.define do
  factory :draft do
    association :draft_transaction
    association :draftable, factory: :person
    draft_action_type { Draft::UPDATE }
    draft_serializer { DraftApprove::Serializers::Json.name }
    draft_changes { {} }
  end

  trait :pending_approval do
    association(:draft_transaction, status: DraftTransaction::PENDING_APPROVAL)
  end

  trait :approved do
    association(:draft_transaction, status: DraftTransaction::APPROVED)
  end

  trait :rejected do
    association(:draft_transaction, status: DraftTransaction::REJECTED)
  end

  trait :approval_error do
    association(:draft_transaction, status: DraftTransaction::APPROVAL_ERROR)
  end

  trait :skip_validations do
    to_create {|instance| instance.save(validate: false)}
  end
end
