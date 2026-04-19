require "rails_helper"

RSpec.describe Invoice do
  it "rejects unsupported attachments" do
    inv = build(:invoice)
    inv.document.attach(io: StringIO.new("x"), filename: "a.exe", content_type: "application/x-msdownload")
    expect(inv).not_to be_valid
    expect(inv.errors[:document]).to be_present
  end

  it "accepts PDFs" do
    inv = build(:invoice)
    inv.document.attach(io: StringIO.new("%PDF-1.4"), filename: "a.pdf", content_type: "application/pdf")
    expect(inv).to be_valid
  end

  it "computes totals from lines and tax" do
    inv = build(:invoice, tax_amount: 10)
    inv.lines.build(description: "A", quantity: 2, unit_price: 50)
    inv.recalculate_totals
    expect([inv.subtotal, inv.total_amount]).to eq([100, 110])
  end

  it "prevents duplicate invoice numbers per supplier" do
    supplier = create(:supplier)
    create(:invoice, company: supplier.company, supplier: supplier, invoice_number: "INV-9")
    dup = build(:invoice, company: supplier.company, supplier: supplier, invoice_number: "INV-9")
    expect(dup).not_to be_valid
  end

  it "follows the processing lifecycle" do
    inv = create(:invoice, :with_document)
    inv.start_processing!
    inv.finish_extraction!
    inv.flag_exception!
    inv.approve!
    inv.mark_paid!
    expect(inv).to be_paid
  end
end
