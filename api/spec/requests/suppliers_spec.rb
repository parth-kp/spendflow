require "rails_helper"

RSpec.describe "Suppliers" do
  let(:company) { create(:company) }
  let(:employee) { create(:user, company: company) }
  let(:finance) { create(:user, :finance, company: company) }

  it "lists suppliers with pagination headers" do
    create_list(:supplier, 3, company: company)
    get "/api/v1/suppliers", headers: auth_headers(employee), params: { per_page: 2 }

    expect(response).to have_http_status(:ok)
    expect(json.size).to eq(2)
    expect(response.headers["X-Total-Count"]).to eq("3")
  end

  it "lets finance create a supplier" do
    post "/api/v1/suppliers", headers: auth_headers(finance),
                              params: { supplier: { name: "Northwind", payment_terms_days: 45 } }

    expect(response).to have_http_status(:created)
    expect(json["name"]).to eq("Northwind")
  end

  it "forbids employees from creating suppliers" do
    post "/api/v1/suppliers", headers: auth_headers(employee), params: { supplier: { name: "X" } }
    expect(response).to have_http_status(:forbidden)
  end

  it "returns validation errors" do
    post "/api/v1/suppliers", headers: auth_headers(finance), params: { supplier: { name: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["details"]).to have_key("name")
  end
end
