require "rails_helper"

RSpec.describe Extraction::InvoiceExtractor do
  let(:invoice) do
    build(:invoice, source: "upload").tap do |inv|
      inv.document.attach(io: file_fixture("invoice.txt").open, filename: "invoice.txt", content_type: "text/plain")
      inv.save!
    end
  end

  context "with the heuristic backend" do
    subject(:result) { described_class.new(invoice, backend: Extraction::HeuristicExtractor.new).call }

    it "reads labelled fields and line items" do
      expect(result["invoice_number"]).to eq("NW-1042")
      expect(result["po_number"]).to eq("PO-00001")
      expect(result["total_amount"]).to eq(660)
      expect(result["line_items"].map { |l| [l["description"], l["quantity"].to_i, l["unit_price"].to_i] })
        .to eq([["A4 copy paper box", 10, 30], ["Laser toner cartridge black", 4, 90]])
    end
  end

  context "with OpenRouter" do
    let(:backend) { Extraction::OpenRouterExtractor.new(api_key: "test-key") }
    let(:model_json) do
      { supplier_name: "Northwind Traders", invoice_number: "NW-1042", invoice_date: "2026-10-14",
        due_date: "2026-11-13", currency: "USD", po_number: "PO-00001", subtotal: 660, tax_amount: 0,
        total_amount: 660, confidence: 0.93,
        line_items: [{ description: "A4 copy paper box", quantity: 10, unit_price: 30, amount: 300 }] }
    end

    it "sends the document text with a strict JSON schema and parses the reply" do
      stub = stub_request(:post, Extraction::OpenRouterExtractor::ENDPOINT)
             .with(headers: { "Authorization" => "Bearer test-key" }) { |req|
               body = JSON.parse(req.body)
               body["response_format"]["type"] == "json_schema" &&
                 body["messages"].last["content"].first["text"].include?("NW-1042")
             }
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: { choices: [{ message: { content: model_json.to_json } }] }.to_json)

      result = described_class.new(invoice, backend: backend).call

      expect(stub).to have_been_requested
      expect(result.source).to eq("openrouter:openai/gpt-4o-mini")
      expect(result["confidence"]).to eq(0.93)
    end

    it "sends images to the vision model" do
      invoice.document.attach(io: StringIO.new("\x89PNG fake"), filename: "scan.png", content_type: "image/png")
      stub = stub_request(:post, Extraction::OpenRouterExtractor::ENDPOINT)
             .with { |req|
               body = JSON.parse(req.body)
               body["model"] == "google/gemini-2.5-flash" &&
                 body["messages"].last["content"].last["image_url"]["url"].start_with?("data:image/png;base64,")
             }
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: { choices: [{ message: { content: model_json.to_json } }] }.to_json)

      described_class.new(invoice, backend: backend).call
      expect(stub).to have_been_requested
    end

    it "wraps API failures" do
      stub_request(:post, Extraction::OpenRouterExtractor::ENDPOINT).to_return(status: 502, body: "bad gateway")
      expect { described_class.new(invoice, backend: backend).call }.to raise_error(described_class::Error, /502/)
    end

    it "wraps malformed JSON" do
      stub_request(:post, Extraction::OpenRouterExtractor::ENDPOINT)
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: { choices: [{ message: { content: "not json" } }] }.to_json)
      expect { described_class.new(invoice, backend: backend).call }.to raise_error(described_class::Error, /invalid JSON/)
    end
  end
end
