require "rails_helper"

RSpec.describe ProcessInvoiceJob do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:supplier) { create(:supplier, company: company, name: "Northwind Traders", payment_terms_days: 30) }
  let!(:po) do
    create(:purchase_order, company: company, supplier: supplier, line_specs: [
      { description: "A4 copy paper box", quantity: 10, unit_price: 30 },
      { description: "Laser toner cartridge black", quantity: 4, unit_price: 90 }
    ]).tap { |p| p.lines.each { |l| l.update!(received_quantity: l.quantity) } }
  end
  let!(:finance) { create(:user, :finance, company: company) }
  let(:invoice) do
    build(:invoice, company: company, uploaded_by: finance, source: "upload").tap do |inv|
      inv.document.attach(io: file_fixture("invoice.txt").open, filename: "invoice.txt", content_type: "text/plain")
      inv.save!
    end
  end

  it "extracts, links the PO and queues matching" do
    expect { described_class.perform_now(company_id: company.id, invoice_id: invoice.id) }
      .to have_enqueued_job(MatchInvoiceJob)

    invoice.reload
    expect(invoice).to be_extracted
    expect(invoice.supplier).to eq(supplier)
    expect(invoice.purchase_order).to eq(po)
    expect(invoice.total_amount).to eq(660)
    expect(invoice.lines.size).to eq(2)
    expect(invoice.audit_events.last.metadata["source"]).to eq("heuristic")
  end

  it "runs end to end to a clean match" do
    perform_enqueued_jobs { described_class.perform_later(company_id: company.id, invoice_id: invoice.id) }

    invoice.reload
    expect(invoice).to be_matched
    expect(invoice.lines.map(&:match_status)).to eq(%w[matched matched])
  end

  it "marks the invoice failed when extraction keeps failing" do
    allow(Extraction::InvoiceExtractor).to receive(:new).and_raise(Extraction::InvoiceExtractor::Error, "boom")

    perform_enqueued_jobs { described_class.perform_later(company_id: company.id, invoice_id: invoice.id) }

    invoice.reload
    expect(invoice).to be_extraction_failed
    expect(invoice.extraction_error).to eq("boom")
  end

  it "fails visibly on unexpected errors instead of hanging in processing" do
    allow(Invoices::ApplyExtraction).to receive(:new).and_raise(ActiveRecord::StatementInvalid, "db hiccup")

    described_class.perform_now(company_id: company.id, invoice_id: invoice.id)

    expect(invoice.reload).to be_extraction_failed
    expect(invoice.extraction_error).to include("db hiccup")
  end

  it "flags a re-uploaded copy as a duplicate rather than failing" do
    perform_enqueued_jobs { described_class.perform_later(company_id: company.id, invoice_id: invoice.id) }

    copy = build(:invoice, company: company, uploaded_by: finance, source: "upload")
    copy.document.attach(io: file_fixture("invoice.txt").open, filename: "copy.txt", content_type: "text/plain")
    copy.save!
    perform_enqueued_jobs { described_class.perform_later(company_id: company.id, invoice_id: copy.id) }

    expect(copy.reload).to be_exception
    expect(copy.match_result["checks"].find { |c| c["name"] == "duplicate" }["passed"]).to be(false)
  end
end
