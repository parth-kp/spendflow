FactoryBot.define do
  factory :department do
    company
    sequence(:name) { |n| "Department #{n}" }
    sequence(:code) { |n| "DEPT#{n}" }
  end
end
