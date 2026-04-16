require "rails_helper"

RSpec.describe "Requisitions" do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:dept) { create(:department, company: company) }
  let(:employee) { create(:user, company: company, department: dept) }
  let(:colleague) { create(:user, company: company, department: dept) }
  let(:manager) { create(:user, :manager, company: company, department: dept) }
  let(:finance) { create(:user, :finance, company: company) }

  let(:payload) do
    { requisition: { title: "Dev laptops", justification: "New hires",
                     lines_attributes: [{ description: "MacBook Pro", quantity: 2, unit_price: 2400 }] } }
  end

  before do
    create(:approval_rule, company: company, level: 1, approver_role: "manager")
    create(:approval_rule, company: company, level: 2, min_amount: 4_000, approver_role: "finance")
  end

  it "creates a draft requisition in the requester's department" do
    post "/api/v1/requisitions", params: payload, headers: auth_headers(employee)

    expect(response).to have_http_status(:created)
    expect(json).to include("status" => "draft", "total_amount" => "4800.0", "number" => "REQ-00001")
    expect(json.dig("department", "id")).to eq(dept.id)
    expect(json.dig("permissions", "submit")).to be(true)
  end

  it "runs the full submit → approve → approve flow" do
    post "/api/v1/requisitions", params: payload, headers: auth_headers(employee)
    id = json["id"]

    post "/api/v1/requisitions/#{id}/submit", headers: auth_headers(employee)
    expect(json["status"]).to eq("pending_approval")
    expect(json["approval_steps"].pluck("approver_role")).to eq(%w[manager finance])

    post "/api/v1/requisitions/#{id}/approve", headers: auth_headers(finance)
    expect(response).to have_http_status(:forbidden)

    post "/api/v1/requisitions/#{id}/approve", params: { comment: "ok" }, headers: auth_headers(manager)
    post "/api/v1/requisitions/#{id}/approve", headers: auth_headers(finance)
    expect(json["status"]).to eq("approved")
  end

  it "hides other people's requisitions from employees" do
    req = create(:requisition, company: company, requester: colleague, department: dept)

    get "/api/v1/requisitions/#{req.id}", headers: auth_headers(employee)
    expect(response).to have_http_status(:forbidden)

    get "/api/v1/requisitions", headers: auth_headers(employee)
    expect(json).to be_empty

    get "/api/v1/requisitions", headers: auth_headers(manager)
    expect(json.pluck("id")).to eq([req.id])
  end

  it "rejects edits once submitted" do
    req = create(:requisition, company: company, requester: employee, department: dept)
    Approvals::Workflow.new(req, actor: employee).submit!

    patch "/api/v1/requisitions/#{req.id}", params: { requisition: { title: "Changed" } }, headers: auth_headers(employee)
    expect(response).to have_http_status(:forbidden)
  end

  it "returns 409 when rejecting without a comment" do
    req = create(:requisition, company: company, requester: employee, department: dept)
    Approvals::Workflow.new(req, actor: employee).submit!

    post "/api/v1/requisitions/#{req.id}/reject", headers: auth_headers(manager)
    expect(response).to have_http_status(:conflict)
    expect(json["error"]).to match(/comment/)
  end

  it "does not accept a supplier from another tenant" do
    foreign = create(:supplier)
    payload[:requisition][:supplier_id] = foreign.id

    post "/api/v1/requisitions", params: payload, headers: auth_headers(employee)
    expect(response).to have_http_status(:unprocessable_content)
  end
end
