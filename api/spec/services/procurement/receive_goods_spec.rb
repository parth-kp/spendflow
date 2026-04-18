require "rails_helper"

RSpec.describe Procurement::ReceiveGoods do
  let(:po) do
    create(:purchase_order, line_specs: [
      { description: "Paper", quantity: 10, unit_price: 5 },
      { description: "Toner", quantity: 2, unit_price: 80 }
    ])
  end
  let(:receiver) { create(:user, company: po.company) }
  let(:paper) { po.lines.first }
  let(:toner) { po.lines.second }

  def receive(quantities, **opts)
    described_class.new(po, actor: receiver, quantities: quantities, **opts).call
  end

  it "records a partial receipt" do
    receipt = receive({ paper.id => 4 })

    expect(receipt.number).to eq("GRN-00001")
    expect(paper.reload.received_quantity).to eq(4)
    expect(po.reload).to be_partially_received
  end

  it "marks the PO received once everything arrives" do
    receive({ paper.id => 4 })
    receive({ paper.id => 6, toner.id => 2 })
    expect(po.reload).to be_received
  end

  it "blocks over-receipt by default" do
    expect { receive({ paper.id => 11 }) }.to raise_error(described_class::Error, /only 10.0 open/)
    expect(paper.reload.received_quantity).to eq(0)
  end

  it "rejects lines from other POs" do
    other = create(:purchase_order, company: po.company)
    expect { receive({ other.lines.first.id => 1 }) }.to raise_error(described_class::Error, /not on/)
  end

  it "refuses to receive against a closed PO" do
    po.close!
    expect { receive({ paper.id => 1 }) }.to raise_error(described_class::Error, /closed/)
  end

  it "audits the receipt" do
    receive({ paper.id => 3 })
    expect(po.audit_events.last.metadata).to include("lines" => { "1" => "3.0" })
  end
end
