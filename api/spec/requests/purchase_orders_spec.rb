require "rails_helper"

RSpec.describe "Purchase orders" do
  let(:company) { create(:company) }
  let(:dept) { create(:department, company: company) }
  let(:requester) { create(:user, company: company, department: dept) }
  let(:stranger) { create(:user, company: company) }
  let(:finance) { create(:user, :finance, company: company) }
  let(:supplier) { create(:supplier, company: company) }
  let(:requisition) do
    create(:requisition, company: company, requester: requester, department: dept, amount: 300).tap do |r|
      r.submit!
      r.approve!
    end
  end

  def convert
    post "/api/v1/purchase_orders", params: { requisition_id: requisition.id, supplier_id: supplier.id },
                                    headers: auth_headers(finance)
  end

  it "lets finance convert an approved requisition" do
    convert
    expect(response).to have_http_status(:created)
    expect(json).to include("number" => "PO-00001", "status" => "issued", "total_amount" => "300.0")
  end

  it "does not let the requester issue POs" do
    post "/api/v1/purchase_orders", params: { requisition_id: requisition.id, supplier_id: supplier.id },
                                    headers: auth_headers(requester)
    expect(response).to have_http_status(:forbidden)
  end

  it "lets the requester record a goods receipt" do
    convert
    po_id = json["id"]
    line_id = json["lines"].first["id"]

    post "/api/v1/purchase_orders/#{po_id}/receive",
         params: { lines: [{ purchase_order_line_id: line_id, quantity: 1 }] }, headers: auth_headers(requester)

    expect(response).to have_http_status(:created)
    expect(json["status"]).to eq("received")
    expect(json["receipts"].first["number"]).to eq("GRN-00001")
  end

  it "hides POs from unrelated employees" do
    convert
    get "/api/v1/purchase_orders", headers: auth_headers(stranger)
    expect(json).to be_empty
  end
end
