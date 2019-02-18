FactoryBot.define do
  factory :draft_transaction do
    status        { DraftTransaction::PENDING_APPROVAL }
    created_by    { "dummy user #{SecureRandom.random_number(10_000)}" }
    serialization { DraftApprove::Serialization::Json.name }
  end
end
