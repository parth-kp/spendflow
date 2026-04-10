FactoryBot.define do
  factory :supplier do
    company
    sequence(:name) { |n| "Supplier #{n}" }
    email { "billing@#{name.parameterize}.test" }
    payment_terms_days { 30 }
  end
end
