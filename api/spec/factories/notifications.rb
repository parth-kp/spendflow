FactoryBot.define do
  factory :notification do
    company
    user { association :user, company: company }
    kind { "info" }
    title { "Something happened" }
  end
end
