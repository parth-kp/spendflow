require "rails_helper"

RSpec.describe Matching::ThreeWayMatch do
  let(:company) { create(:company, price_tolerance_pct: 2, quantity_tolerance_pct: 0) }
  let(:supplier) { create(:supplier, company: company) }
  let(:po) do
    create(:purchase_order, company: company, supplier: supplier, line_specs: [
      { description: "A4 copy paper box", quantity: 10, unit_price: 30 },
      { description: "Laser toner cartridge black", quantity: 4, unit_price: 90 }
    ])
  end
  let(:paper) { po.lines.first }
  let(:toner) { po.lines.second }

  def receive(line, qty)
    line.update!(received_quantity: qty)
  end

  def invoice_with(*lines, **attrs)
    create(:invoice, company: company, supplier: supplier, purchase_order: po, **attrs).tap do |inv|
      lines.each_with_index { |l, i| inv.lines.create!(l.merge(position: i)) }
      inv.lines.reload
    end
  end

  def run(inv) = described_class.new(inv).call

  it "matches when price and received quantity line up" do
    receive(paper, 10)
    receive(toner, 4)
    inv = invoice_with({ description: "Copy paper A4 (box)", quantity: 10, unit_price: 30 },
                       { description: "Toner cartridge - black", quantity: 4, unit_price: 90 })

    result = run(inv)
    expect(result).to be_matched
    expect(result.lines.map { |l| l[:purchase_order_line_id] }).to eq([paper.id, toner.id])
  end

  it "tolerates small price differences" do
    receive(paper, 10)
    inv = invoice_with({ description: "A4 copy paper box", quantity: 10, unit_price: 30.5 })
    expect(run(inv)).to be_matched
  end

  it "flags price variance beyond tolerance" do
    receive(paper, 10)
    inv = invoice_with({ description: "A4 copy paper box", quantity: 10, unit_price: 33 })

    result = run(inv)
    expect(result.status).to eq("exception")
    expect(result.lines.first[:status]).to eq("price_variance")
    expect(result.lines.first[:notes].first).to include("+10.0%")
  end

  it "flags billing for goods that were not received" do
    receive(paper, 6)
    inv = invoice_with({ description: "A4 copy paper box", quantity: 10, unit_price: 30 })

    line = run(inv).lines.first
    expect(line[:status]).to eq("quantity_variance")
    expect(line[:notes].first).to include("only 6.0 received")
  end

  it "accounts for quantities already invoiced" do
    receive(paper, 10)
    paper.update!(invoiced_quantity: 8)
    inv = invoice_with({ description: "A4 copy paper box", quantity: 5, unit_price: 30 })
    expect(run(inv).lines.first[:status]).to eq("quantity_variance")
  end

  it "reports lines that are not on the PO" do
    receive(paper, 10)
    inv = invoice_with({ description: "A4 copy paper box", quantity: 10, unit_price: 30 },
                       { description: "Expedited shipping fee", quantity: 1, unit_price: 45 })
    expect(run(inv).lines.last[:status]).to eq("unmatched")
  end

  it "fails the header check for a different supplier" do
    receive(paper, 10)
    inv = invoice_with({ description: "A4 copy paper box", quantity: 10, unit_price: 30 },
                       supplier: create(:supplier, company: company))
    expect(run(inv).checks.find { |c| c[:name] == "supplier" }[:passed]).to be(false)
  end

  it "is an exception when no PO is linked" do
    inv = create(:invoice, company: company)
    expect(run(inv).checks.map { |c| c[:name] }).to include("purchase_order")
  end

  it "flags a duplicate of an earlier invoice" do
    receive(paper, 10)
    first = invoice_with({ description: "A4 copy paper box", quantity: 10, unit_price: 30 }, invoice_number: "NW-1")
    second = invoice_with({ description: "A4 copy paper box", quantity: 10, unit_price: 30 }, invoice_number: "NW-1")

    expect(run(first)).to be_matched
    result = run(second)
    expect(result.status).to eq("exception")
    expect(result.checks.find { |c| c[:name] == "duplicate" }[:message]).to include("##{first.id}")
  end
end
