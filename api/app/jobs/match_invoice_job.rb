class MatchInvoiceJob < ApplicationJob
  queue_as :invoices

  def perform(company_id:, invoice_id:)
    with_company(company_id) do
      invoice = Invoice.find(invoice_id)
      Invoices::RunMatch.new(invoice).call if invoice.matchable?
    end
  end
end
