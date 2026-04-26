require "rails_helper"

RSpec.describe "Audit log, notifications and dashboard" do
  let(:company) { create(:company) }
  let(:dept) { create(:department, company: company) }
  let(:employee) { create(:user, company: company, department: dept) }
  let(:manager) { create(:user, :manager, company: company, department: dept) }
  let(:finance) { create(:user, :finance, company: company) }

  let!(:requisition) do
    create(:approval_rule, company: company, level: 1, approver_role: "manager")
    req = create(:requisition, company: company, requester: employee, department: dept)
    ActsAsTenant.with_tenant(company) do
      Approvals::Workflow.new(req, actor: employee).submit!
      Approvals::Workflow.new(req, actor: manager).decide!(:approve, comment: "LGTM")
    end
    req
  end

  it "shows a record's history to anyone who can see the record" do
    get "/api/v1/audit_events", headers: auth_headers(employee),
                                params: { auditable_type: "Requisition", auditable_id: requisition.id }

    expect(json.pluck("action")).to eq(%w[submitted step_approved approved])
    expect(json.second.dig("actor", "name")).to eq(manager.name)
    expect(json.second.dig("metadata", "comment")).to eq("LGTM")
  end

  it "restricts the global log to finance and admins" do
    get "/api/v1/audit_events", headers: auth_headers(employee)
    expect(json).to be_empty

    get "/api/v1/audit_events", headers: auth_headers(finance)
    expect(json.size).to eq(3)
    expect(json.first.dig("auditable", "label")).to eq(requisition.number)
  end

  it "rejects unknown auditable types" do
    get "/api/v1/audit_events", headers: auth_headers(finance), params: { auditable_type: "User", auditable_id: 1 }
    expect(response).to have_http_status(:not_found)
  end

  it "lists and clears notifications" do
    create(:notification, user: employee, company: company)
    create(:notification, user: manager, company: company)

    get "/api/v1/notifications", headers: auth_headers(employee)
    expect(json.size).to eq(1)
    expect(response.headers["X-Unread-Count"]).to eq("1")

    post "/api/v1/notifications/read_all", headers: auth_headers(employee)
    get "/api/v1/notifications", headers: auth_headers(employee), params: { unread: "true" }
    expect(json).to be_empty
  end

  it "returns dashboard metrics by role" do
    get "/api/v1/dashboard", headers: auth_headers(employee)
    expect(json["my_requisitions"]).to eq("approved" => 1)
    expect(json).not_to have_key("spend_by_department")

    get "/api/v1/dashboard", headers: auth_headers(finance)
    expect(json["spend_by_department"]).to eq(dept.name => "1000.0")
  end
end
