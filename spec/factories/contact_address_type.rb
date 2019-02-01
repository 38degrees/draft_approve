FactoryBot.define do
  factory :contact_address_type do
    name { "dummy contact address type #{SecureRandom.random_number(10_000)}" }
  end
end
