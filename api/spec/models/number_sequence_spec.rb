require "rails_helper"

RSpec.describe NumberSequence do
  it "increments per company and prefix" do
    a = create(:company)
    b = create(:company)

    expect(described_class.next_for(a, "REQ")).to eq("REQ-00001")
    expect(described_class.next_for(a, "REQ")).to eq("REQ-00002")
    expect(described_class.next_for(a, "PO")).to eq("PO-00001")
    expect(described_class.next_for(b, "REQ")).to eq("REQ-00001")
  end
end
