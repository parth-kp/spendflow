module Invoices
  class ApplyExtraction
    def initialize(invoice, result)
      @invoice = invoice
      @result = result
    end

    def call
      supplier = invoice.supplier || Matching::SupplierResolver.call(result["supplier_name"])
      po = invoice.purchase_order || Matching::PurchaseOrderFinder.new(
        po_number: result["po_number"], supplier: supplier, total: result["total_amount"]
      ).call
      supplier ||= po&.supplier

      invoice.assign_attributes(
        supplier: supplier,
        purchase_order: po,
        invoice_number: result["invoice_number"],
        invoice_date: result["invoice_date"],
        due_date: result["due_date"] || default_due_date(supplier),
        currency: result["currency"] || po&.currency || invoice.company.currency,
        tax_amount: result["tax_amount"] || 0,
        extraction: result.to_h,
        extraction_error: nil
      )
      invoice.lines.destroy_all
      result["line_items"].each_with_index do |item, i|
        invoice.lines.build(position: i, description: item["description"], quantity: item["quantity"],
                            unit_price: item["unit_price"], amount: item["amount"])
      end
      invoice.recalculate_totals
      invoice.total_amount = result["total_amount"] if result["line_items"].empty?
      invoice
    end

    private

    attr_reader :invoice, :result

    def default_due_date(supplier)
      return unless supplier && result["invoice_date"]

      result["invoice_date"] + supplier.payment_terms_days
    end
  end
end
