FactoryBot.define do
  factory :gender do
    name { "dummy gender #{SecureRandom.random_number(10_000)}" }
  end
end
