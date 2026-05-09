require "rails_helper"

RSpec.describe "Administration" do
  let(:company) { create(:company) }
  let(:admin) { create(:user, :admin, company: company) }
  let(:employee) { create(:user, company: company) }
  let(:dept) { create(:department, company: company) }

  it "lets admins invite users" do
    post "/api/v1/users", headers: auth_headers(admin), params: {
      user: { name: "Nia", email: "nia@example.com", role: "manager", department_id: dept.id, password: "longpassword" }
    }
    expect(response).to have_http_status(:created)
    expect(json).to include("role" => "manager")
  end

  it "ignores role changes from non-admins" do
    patch "/api/v1/users/#{employee.id}", headers: auth_headers(employee), params: { user: { role: "admin" } }
    expect(response).to have_http_status(:forbidden)
    expect(employee.reload.role).to eq("employee")
  end

  it "manages approval rules and previews a chain" do
    post "/api/v1/approval_rules", headers: auth_headers(admin),
                                   params: { approval_rule: { name: "Mgr", level: 1, min_amount: 0, approver_role: "manager" } }
    post "/api/v1/approval_rules", headers: auth_headers(admin),
                                   params: { approval_rule: { name: "CFO", level: 2, min_amount: 10_000, approver_role: "finance" } }

    get "/api/v1/approval_rules/preview", headers: auth_headers(admin), params: { amount: 12_000 }
    expect(json.pluck("name")).to eq(%w[Mgr CFO])
  end

  it "forbids employees from editing rules" do
    post "/api/v1/approval_rules", headers: auth_headers(employee),
                                   params: { approval_rule: { name: "x", level: 1, approver_role: "manager" } }
    expect(response).to have_http_status(:forbidden)
  end

  it "lists departments with headcount" do
    create(:user, company: company, department: dept)
    get "/api/v1/departments", headers: auth_headers(employee)
    expect(json.first).to include("code" => dept.code, "user_count" => 1)
  end

  it "lets anyone preview who will approve an amount" do
    create(:approval_rule, company: company, name: "Mgr", level: 1, approver_role: "manager")
    get "/api/v1/approval_rules/preview", headers: auth_headers(employee), params: { amount: 100 }
    expect(json.pluck("name")).to eq(%w[Mgr])
  end
end
