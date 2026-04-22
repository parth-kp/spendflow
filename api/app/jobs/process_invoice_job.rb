class ProcessInvoiceJob < ApplicationJob
  queue_as :invoices

  retry_on Extraction::InvoiceExtractor::Error, wait: 10.seconds, attempts: 2 do |job, error|
    job.mark_failed(error)
  end

  def perform(company_id:, invoice_id:)
    with_company(company_id) do
      invoice = Invoice.find(invoice_id)
      return unless invoice.uploaded? || invoice.processing? || invoice.extraction_failed?

      invoice.start_processing! unless invoice.processing?
      result = Extraction::InvoiceExtractor.new(invoice).call

      invoice.transaction do
        Invoices::ApplyExtraction.new(invoice, result).call
        invoice.finish_extraction!
        invoice.audit!(:extracted, actor: nil, source: result.source, confidence: result["confidence"],
                                   warnings: result.warnings)
      end

      MatchInvoiceJob.perform_later(company_id: company_id, invoice_id: invoice.id)
    end
  end

  def mark_failed(error)
    kwargs = arguments.first
    with_company(kwargs[:company_id]) do
      invoice = Invoice.find(kwargs[:invoice_id])
      invoice.update!(extraction_error: error.message.truncate(500))
      invoice.fail_extraction! if invoice.processing?
      invoice.audit!(:extraction_failed, actor: nil, error: error.message.truncate(200))
    end
  end
end
