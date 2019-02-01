FactoryBot.define do
  factory :contact_address do
    association :contact_address_type
    association :contactable, factory: :person
    value { "dummy value #{SecureRandom.random_number(10_000)}" }
  end
end
