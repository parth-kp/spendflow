require "rails_helper"

RSpec.describe Company do
  it { is_expected.to validate_presence_of(:name) }

  it "derives the slug from the name" do
    company = create(:company, name: "Globex Corp")
    expect(company.slug).to eq("globex-corp")
  end

  it "rejects tolerances above 100%" do
    company = build(:company, price_tolerance_pct: 150)
    expect(company).not_to be_valid
  end
end
