require "rails_helper"

RSpec.describe Matching::JevAdvisor do
  let(:po) { create(:purchase_order) }
  let(:invoice) { create(:invoice, company: po.company, purchase_order: po, total_amount: 250) }

  it "returns the Noul probability" do
    stub = stub_request(:post, described_class::ENDPOINT)
           .with(headers: { "Authorization" => "Bearer ts-key" }) { |r| JSON.parse(r.body).dig("questions", "same_purchase", "type") == "noul" }
           .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                      body: { answers: { same_purchase: { type: "noul", noul: 0.9312 } } }.to_json)

    expect(described_class.new(api_key: "ts-key").probability(invoice, po)).to eq(BigDecimal("0.9312"))
    expect(stub).to have_been_requested
  end

  it "returns nil without a key" do
    expect(described_class.new(api_key: nil).probability(invoice, po)).to be_nil
  end

  it "swallows transport errors" do
    stub_request(:post, described_class::ENDPOINT).to_timeout
    expect(described_class.new(api_key: "k").probability(invoice, po)).to be_nil
  end
end
