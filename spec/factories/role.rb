FactoryBot.define do
  factory :role do
    name { "dummy role #{SecureRandom.random_number(10_000)}" }
  end
end
