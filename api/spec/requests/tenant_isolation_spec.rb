require "rails_helper"

RSpec.describe "Tenant isolation" do
  let(:acme) { create(:company, name: "Acme") }
  let(:globex) { create(:company, name: "Globex") }
  let(:acme_admin) { create(:user, :admin, company: acme) }
  let!(:globex_supplier) { create(:supplier, company: globex) }
  let!(:globex_requisition) { create(:requisition, company: globex) }

  it "does not list another company's records" do
    create(:supplier, company: acme, name: "Acme Paper")

    get "/api/v1/suppliers", headers: auth_headers(acme_admin)
    expect(json.pluck("name")).to eq(["Acme Paper"])

    get "/api/v1/requisitions", headers: auth_headers(acme_admin)
    expect(json).to be_empty
  end

  it "returns 404 for another company's record ids" do
    get "/api/v1/suppliers/#{globex_supplier.id}", headers: auth_headers(acme_admin)
    expect(response).to have_http_status(:not_found)

    get "/api/v1/requisitions/#{globex_requisition.id}", headers: auth_headers(acme_admin)
    expect(response).to have_http_status(:not_found)
  end

  it "cannot act on another company's requisition" do
    post "/api/v1/requisitions/#{globex_requisition.id}/submit", headers: auth_headers(acme_admin)
    expect(response).to have_http_status(:not_found)
    expect(globex_requisition.reload).to be_draft
  end

  it "rejects tokens whose user moved companies" do
    token_user = create(:user, company: acme)
    headers = auth_headers(token_user)
    token_user.update_columns(company_id: globex.id)

    get "/api/v1/session", headers: headers
    expect(response).to have_http_status(:unauthorized)
  end
end
