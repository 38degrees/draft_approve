FactoryBot.define do
  factory :person do
    name { "dummy person #{SecureRandom.random_number(10_000)}" }
  end
end
