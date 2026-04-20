require "rails_helper"

RSpec.describe Matching::PurchaseOrderFinder do
  let(:company) { create(:company) }
  let(:supplier) { create(:supplier, company: company, name: "Northwind Traders") }
  let!(:small) { create(:purchase_order, company: company, supplier: supplier, line_specs: [{ description: "A", quantity: 1, unit_price: 100 }]) }
  let!(:large) { create(:purchase_order, company: company, supplier: supplier, line_specs: [{ description: "B", quantity: 1, unit_price: 900 }]) }

  around { |ex| ActsAsTenant.with_tenant(company) { ex.run } }

  it "uses a quoted PO number, tolerating formatting" do
    found = described_class.new(po_number: "po 2", supplier: nil, total: nil).call
    expect(found).to eq(large)
  end

  it "falls back to the supplier PO with the closest total" do
    expect(described_class.new(po_number: nil, supplier: supplier, total: 880).call).to eq(large)
    expect(described_class.new(po_number: nil, supplier: supplier, total: 120).call).to eq(small)
  end

  it "ignores closed POs" do
    large.close!
    expect(described_class.new(po_number: nil, supplier: supplier, total: 880).call).to eq(small)
  end

  it "resolves suppliers despite legal suffixes" do
    expect(Matching::SupplierResolver.call("NORTHWIND TRADERS, INC.")).to eq(supplier)
  end
end
