FactoryBot.define do
  factory :invoice do
    company
    uploaded_by { association :user, :finance, company: company }
    source { "manual" }
    currency { "USD" }
    tax_amount { 0 }

    trait :with_document do
      source { "upload" }
      after(:build) do |inv|
        inv.document.attach(io: StringIO.new("INVOICE INV-1 Total 100.00"), filename: "inv.txt", content_type: "text/plain")
      end
    end
  end
end
