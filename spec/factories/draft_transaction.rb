FactoryBot.define do
  factory :draft_transaction do
    user { "dummy user #{SecureRandom.random_number(10_000)}" }
  end
end
