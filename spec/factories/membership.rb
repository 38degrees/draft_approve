FactoryBot.define do
  factory :membership do
    association :person
    association :organization
  end
end
