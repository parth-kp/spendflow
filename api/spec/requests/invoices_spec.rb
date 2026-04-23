require "rails_helper"

RSpec.describe "Invoices" do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:finance) { create(:user, :finance, company: company) }
  let(:controller_user) { create(:user, :finance, company: company) }
  let(:employee) { create(:user, company: company) }
  let(:supplier) { create(:supplier, company: company, name: "Northwind Traders") }
  let!(:po) do
    create(:purchase_order, company: company, supplier: supplier, line_specs: [
      { description: "A4 copy paper box", quantity: 10, unit_price: 30 },
      { description: "Laser toner cartridge black", quantity: 4, unit_price: 90 }
    ]).tap { |p| p.lines.each { |l| l.update!(received_quantity: l.quantity) } }
  end

  let(:upload) { fixture_file_upload("invoice.txt", "text/plain") }

  it "accepts an upload and processes it in the background" do
    post "/api/v1/invoices", params: { document: upload }, headers: auth_headers(finance)

    expect(response).to have_http_status(:created)
    expect(json["status"]).to eq("uploaded")
    expect(ProcessInvoiceJob).to have_been_enqueued.with(company_id: company.id, invoice_id: json["id"])
  end

  it "goes from upload to matched to approved to paid" do
    perform_enqueued_jobs do
      post "/api/v1/invoices", params: { document: upload }, headers: auth_headers(finance)
    end
    id = json["id"]

    get "/api/v1/invoices/#{id}", headers: auth_headers(controller_user)
    expect(json).to include("status" => "matched", "invoice_number" => "NW-1042")
    expect(json.dig("purchase_order", "number")).to eq(po.number)
    expect(json.dig("permissions", "approve")).to be(true)

    post "/api/v1/invoices/#{id}/approve", headers: auth_headers(finance)
    expect(response).to have_http_status(:forbidden)

    post "/api/v1/invoices/#{id}/approve", headers: auth_headers(controller_user)
    expect(json["status"]).to eq("approved")

    post "/api/v1/invoices/#{id}/pay", params: { reference: "ACH-1" }, headers: auth_headers(controller_user)
    expect(json["status"]).to eq("paid")
  end

  it "creates manual invoices and flags price variances" do
    post "/api/v1/invoices", headers: auth_headers(finance), params: {
      invoice: { supplier_id: supplier.id, purchase_order_id: po.id, invoice_number: "M-1",
                 lines_attributes: [{ description: "A4 copy paper box", quantity: 10, unit_price: 40 }] }
    }

    expect(json["status"]).to eq("exception")
    expect(json["lines"].first["match_status"]).to eq("price_variance")
  end

  it "re-matches after a correction" do
    post "/api/v1/invoices", headers: auth_headers(finance), params: {
      invoice: { supplier_id: supplier.id, purchase_order_id: po.id,
                 lines_attributes: [{ description: "A4 copy paper box", quantity: 10, unit_price: 40 }] }
    }
    line_id = json["lines"].first["id"]

    patch "/api/v1/invoices/#{json['id']}", headers: auth_headers(finance),
                                            params: { invoice: { lines_attributes: [{ id: line_id, unit_price: 30 }] } }
    expect(json["status"]).to eq("matched")
    expect(json["total_amount"]).to eq("300.0")
  end

  it "serves the original document" do
    post "/api/v1/invoices", params: { document: upload }, headers: auth_headers(finance)
    get "/api/v1/invoices/#{json['id']}/document", headers: auth_headers(finance)

    expect(response.body).to include("NW-1042")
    expect(response.media_type).to eq("text/plain")
  end

  it "is off limits to employees" do
    get "/api/v1/invoices", headers: auth_headers(employee)
    expect(json).to eq([])

    post "/api/v1/invoices", params: { document: upload }, headers: auth_headers(employee)
    expect(response).to have_http_status(:forbidden)
  end
end
