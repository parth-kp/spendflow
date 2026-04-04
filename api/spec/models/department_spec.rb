require "rails_helper"

RSpec.describe Department do
  it "upcases the code" do
    expect(create(:department, code: "eng").code).to eq("ENG")
  end

  it "keeps codes unique within a company only" do
    a = create(:company)
    b = create(:company)
    create(:department, company: a, code: "OPS")

    expect(build(:department, company: a, code: "OPS")).not_to be_valid
    expect(build(:department, company: b, code: "OPS")).to be_valid
  end
end
