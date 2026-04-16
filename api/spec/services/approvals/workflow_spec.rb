require "rails_helper"

RSpec.describe Approvals::Workflow do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:dept) { create(:department, company: company) }
  let(:other_dept) { create(:department, company: company) }
  let(:requester) { create(:user, company: company, department: dept) }
  let(:manager) { create(:user, :manager, company: company, department: dept) }
  let(:foreign_manager) { create(:user, :manager, company: company, department: other_dept) }
  let(:finance) { create(:user, :finance, company: company) }

  before do
    ActsAsTenant.current_tenant = company
    create(:approval_rule, company: company, level: 1, min_amount: 0, approver_role: "manager")
    create(:approval_rule, company: company, level: 2, min_amount: 5_000, approver_role: "finance")
  end

  after { ActsAsTenant.current_tenant = nil }

  def requisition(amount)
    create(:requisition, company: company, requester: requester, department: dept, amount: amount)
  end

  def workflow(req, actor) = described_class.new(req, actor: actor)

  it "creates one step per matching level on submit" do
    req = workflow(requisition(8_000), requester).submit!

    expect(req).to be_pending_approval
    expect(req.approval_steps.map(&:approver_role)).to eq(%w[manager finance])
  end

  it "notifies the department manager on submit" do
    manager
    foreign_manager
    expect { workflow(requisition(100), requester).submit! }
      .to have_enqueued_job(NotifyUsersJob).with(hash_including(user_ids: [manager.id], kind: "approval_requested"))
  end

  it "auto-approves when no rule matches" do
    ApprovalRule.delete_all
    req = workflow(requisition(100), requester).submit!

    expect(req).to be_approved
    expect(req.audit_events.map(&:action)).to eq(%w[submitted auto_approved])
  end

  it "walks levels in order and approves at the end" do
    req = workflow(requisition(8_000), requester).submit!

    workflow(req, manager).decide!(:approve, comment: "ok")
    expect(req.reload).to be_pending_approval
    expect(req.current_step.approver_role).to eq("finance")

    workflow(req, finance).decide!(:approve)
    expect(req.reload).to be_approved
    expect(req.approval_steps.map(&:decided_by)).to eq([manager, finance])
  end

  it "does not let finance skip ahead of the manager" do
    req = workflow(requisition(8_000), requester).submit!
    expect { workflow(req, finance).decide!(:approve) }.to raise_error(described_class::Error, /cannot act/)
  end

  it "does not let a manager from another department approve" do
    req = workflow(requisition(100), requester).submit!
    expect { workflow(req, foreign_manager).decide!(:approve) }.to raise_error(described_class::Error)
  end

  it "never lets requesters approve their own requisition" do
    self_requester = create(:user, :manager, company: company, department: dept)
    req = create(:requisition, company: company, requester: self_requester, department: dept, amount: 100)
    workflow(req, self_requester).submit!

    expect { workflow(req, self_requester).decide!(:approve) }.to raise_error(described_class::Error)
  end

  it "requires a comment on rejection and skips remaining steps" do
    req = workflow(requisition(8_000), requester).submit!
    expect { workflow(req, manager).decide!(:reject) }.to raise_error(described_class::Error, /comment/)

    workflow(req, manager).decide!(:reject, comment: "Over budget")
    expect(req.reload).to be_rejected
    expect(req.approval_steps.map(&:status)).to eq(%w[rejected skipped])
  end

  it "writes an audit trail of who approved what" do
    req = workflow(requisition(8_000), requester).submit!
    workflow(req, manager).decide!(:approve, comment: "fine")
    workflow(req, finance).decide!(:approve)

    events = req.audit_events.reload
    expect(events.map(&:action)).to eq(%w[submitted step_approved step_approved approved])
    expect(events.second.actor).to eq(manager)
    expect(events.second.metadata).to include("level" => 1, "comment" => "fine")
  end
end
