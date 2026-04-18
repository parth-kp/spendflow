require "rails_helper"

RSpec.describe Procurement::IssuePurchaseOrder do
  let(:company) { create(:company) }
  let(:finance) { create(:user, :finance, company: company) }
  let(:supplier) { create(:supplier, company: company) }
  let(:requisition) do
    create(:requisition, company: company).tap do |r|
      r.lines.first.update!(quantity: 4, unit_price: 125)
      r.save!
      r.submit!
      r.approve!
    end
  end

  it "copies lines and totals into a new PO" do
    po = described_class.new(requisition, actor: finance, supplier: supplier).call

    expect(po.number).to eq("PO-00001")
    expect(po.total_amount).to eq(500)
    expect(po.lines.map { |l| [l.line_no, l.quantity.to_i] }).to eq([[1, 4]])
    expect(requisition.reload).to be_ordered
  end

  it "requires a supplier" do
    expect { described_class.new(requisition, actor: finance).call }.to raise_error(described_class::Error, /supplier/)
  end

  it "refuses unapproved requisitions" do
    draft = create(:requisition, company: company)
    expect { described_class.new(draft, actor: finance, supplier: supplier).call }
      .to raise_error(described_class::Error, /approved/)
  end

  it "audits both documents" do
    po = described_class.new(requisition, actor: finance, supplier: supplier).call
    expect(requisition.audit_events.last.action).to eq("converted_to_po")
    expect(po.audit_events.last).to have_attributes(action: "issued", actor: finance)
  end
end
