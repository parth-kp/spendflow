require "rails_helper"

RSpec.describe Invoices::Approve do
  let(:po) { create(:purchase_order, line_specs: [{ description: "Widget", quantity: 10, unit_price: 25 }]) }
  let(:po_line) { po.lines.first }
  let(:finance) { create(:user, :finance, company: po.company) }
  let(:invoice) do
    create(:invoice, company: po.company, purchase_order: po, supplier: po.supplier).tap do |inv|
      inv.lines.create!(description: "Widget", quantity: 4, unit_price: 25, purchase_order_line: po_line)
      inv.finish_extraction!
    end
  end

  it "approves a matched invoice and books invoiced quantity" do
    invoice.mark_matched!
    described_class.new(invoice, actor: finance).call

    expect(invoice).to be_approved
    expect(po_line.reload.invoiced_quantity).to eq(4)
    expect(invoice.audit_events.last).to have_attributes(action: "approved", actor: finance)
  end

  it "requires a justification to override an exception" do
    invoice.flag_exception!
    expect { described_class.new(invoice, actor: finance).call }.to raise_error(described_class::Error)

    described_class.new(invoice, actor: finance, comment: "Price increase agreed by phone").call
    expect(invoice.audit_events.last.metadata).to include("override" => true)
  end
end
