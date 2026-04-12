require "rails_helper"

RSpec.describe ApprovalRule do
  let(:company) { create(:company) }
  let(:eng) { create(:department, company: company) }
  let(:ops) { create(:department, company: company) }

  before do
    create(:approval_rule, company: company, level: 1, min_amount: 0, approver_role: "manager")
    create(:approval_rule, company: company, level: 2, min_amount: 5_000, approver_role: "finance")
    create(:approval_rule, company: company, level: 3, min_amount: 50_000, approver_role: "admin")
    create(:approval_rule, company: company, department: eng, level: 2, min_amount: 2_000, approver_role: "finance",
                           name: "Eng finance review")
  end

  def chain(dept, amount)
    ActsAsTenant.with_tenant(company) { described_class.chain_for(department: dept, amount: amount) }
  end

  it "only needs a manager for small amounts" do
    expect(chain(ops, 500).map(&:approver_role)).to eq(%w[manager])
  end

  it "adds finance above the company threshold" do
    expect(chain(ops, 6_000).map(&:approver_role)).to eq(%w[manager finance])
  end

  it "uses the department override when it applies" do
    rules = chain(eng, 3_000)
    expect(rules.map(&:level)).to eq([1, 2])
    expect(rules.last.name).to eq("Eng finance review")
  end

  it "builds the full chain for large spend" do
    expect(chain(ops, 75_000).map(&:approver_role)).to eq(%w[manager finance admin])
  end

  it "requires named approvers to hold an approver role" do
    rule = build(:approval_rule, company: company, approver: create(:user, company: company))
    expect(rule).not_to be_valid
  end
end
