require "rails_helper"

RSpec.describe ApprovalInboxQuery do
  let(:company) { create(:company) }
  let(:eng) { create(:department, company: company) }
  let(:ops) { create(:department, company: company) }
  let(:eng_manager) { create(:user, :manager, company: company, department: eng) }
  let(:ops_manager) { create(:user, :manager, company: company, department: ops) }
  let(:finance) { create(:user, :finance, company: company) }
  let(:admin) { create(:user, :admin, company: company) }
  let(:engineer) { create(:user, company: company, department: eng) }

  before do
    ActsAsTenant.current_tenant = company
    create(:approval_rule, company: company, level: 1, approver_role: "manager")
    create(:approval_rule, company: company, level: 2, min_amount: 5_000, approver_role: "finance")
  end

  after { ActsAsTenant.current_tenant = nil }

  def submitted(amount, requester: engineer)
    req = create(:requisition, company: company, requester: requester, department: requester.department, amount: amount)
    Approvals::Workflow.new(req, actor: requester).submit!
  end

  def inbox(user) = described_class.new(user).call.to_a

  it "shows level-1 items only to the department manager" do
    req = submitted(9_000)
    expect(inbox(eng_manager)).to eq([req])
    expect(inbox(ops_manager)).to be_empty
    expect(inbox(finance)).to be_empty
  end

  it "moves to finance after the manager approves" do
    req = submitted(9_000)
    Approvals::Workflow.new(req, actor: eng_manager).decide!(:approve)

    expect(inbox(eng_manager)).to be_empty
    expect(inbox(finance)).to eq([req])
  end

  it "lets admins see everything except their own requests" do
    req = submitted(100)
    admin.update!(department: eng)
    own = submitted(100, requester: admin)
    expect(inbox(admin)).to eq([req])
    expect(inbox(admin)).not_to include(own)
  end

  it "agrees with ApprovalStep#actionable_by?" do
    reqs = [submitted(100), submitted(9_000)]
    Approvals::Workflow.new(reqs.last, actor: eng_manager).decide!(:approve)

    [eng_manager, ops_manager, finance, admin, engineer].each do |user|
      expected = reqs.select { |r| r.reload.current_step&.actionable_by?(user) }
      expect(inbox(user)).to match_array(expected), "mismatch for #{user.role}"
    end
  end
end
