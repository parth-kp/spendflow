FactoryBot.define do
  factory :user do
    company
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { "employee" }

    %w[manager finance admin].each do |r|
      trait(r.to_sym) { role { r } }
    end
  end
end
