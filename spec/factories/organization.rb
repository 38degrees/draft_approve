FactoryBot.define do
  factory :organization do
    name { "dummy organization #{SecureRandom.random_number(10_000)}" }
  end
end
