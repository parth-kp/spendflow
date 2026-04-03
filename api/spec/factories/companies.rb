FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Acme #{n}" }
    currency { "USD" }
  end
end
