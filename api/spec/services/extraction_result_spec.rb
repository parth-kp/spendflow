require "rails_helper"

RSpec.describe Extraction::Result do
  let(:raw) do
    { "supplier_name" => " Northwind Traders ", "invoice_number" => "INV-77", "invoice_date" => "2026-10-02",
      "due_date" => "Nov 1, 2026", "currency" => "$", "po_number" => "po-00003", "subtotal" => "1,200.00",
      "tax_amount" => 96, "total_amount" => 1296, "confidence" => 1.4,
      "line_items" => [{ "description" => "Chair", "quantity" => 4, "unit_price" => nil, "amount" => 1200 },
                       { "description" => "", "quantity" => 1, "unit_price" => 1, "amount" => 1 }] }
  end

  subject(:result) { described_class.from_raw(raw, source: "test") }

  it "normalizes values" do
    expect(result["supplier_name"]).to eq("Northwind Traders")
    expect(result["due_date"]).to eq(Date.new(2026, 11, 1))
    expect(result["currency"]).to eq("USD")
    expect(result["po_number"]).to eq("PO-00003")
    expect(result["subtotal"]).to eq(BigDecimal("1200"))
    expect(result["confidence"]).to eq(1.0)
  end

  it "derives missing unit prices and drops blank lines" do
    expect(result["line_items"].size).to eq(1)
    expect(result["line_items"].first["unit_price"]).to eq(300)
  end

  it "warns when lines do not add up" do
    raw["subtotal"] = 999
    expect(result.warnings.first).to match(/add up/)
  end

  it "rejects empty extractions" do
    expect { described_class.from_raw({}, source: "test") }.to raise_error(described_class::Invalid)
  end

  it "serializes to JSON-safe values" do
    expect(result.to_h).to include("invoice_date" => "2026-10-02", "total_amount" => "1296.0", "source" => "test")
  end
end
