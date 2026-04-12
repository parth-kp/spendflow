FactoryBot.define do
  factory :approval_rule do
    company
    sequence(:name) { |n| "Rule #{n}" }
    level { 1 }
    min_amount { 0 }
    approver_role { "manager" }
  end

  factory :approval_step do
    requisition
    company { requisition.company }
    level { 1 }
    approver_role { "manager" }
  end
end
