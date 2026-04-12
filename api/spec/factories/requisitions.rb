FactoryBot.define do
  factory :requisition do
    company
    requester { association :user, company: company, department: department }
    department { association :department, company: company }
    sequence(:title) { |n| "Laptops batch #{n}" }

    transient do
      amount { 1000 }
    end

    after(:build) do |req, ctx|
      req.lines.build(description: "Item", quantity: 1, unit_price: ctx.amount) if req.lines.empty?
    end
  end
end
