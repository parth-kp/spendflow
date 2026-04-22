module Invoices
  class Approve
    class Error < StandardError; end

    def initialize(invoice, actor:, comment: nil)
      @invoice = invoice
      @actor = actor
      @comment = comment
    end

    def call
      invoice.with_lock do
        if invoice.exception? && comment.blank?
          raise Error, "Approving an invoice with match exceptions requires a comment"
        end

        override = invoice.exception?
        invoice.lines.includes(:purchase_order_line).each do |line|
          next unless line.purchase_order_line

          po_line = line.purchase_order_line
          po_line.update!(invoiced_quantity: po_line.invoiced_quantity + line.quantity)
        end

        invoice.approved_by = actor
        invoice.approve!
        invoice.audit!(:approved, actor: actor, override: override, comment: comment,
                                  total: invoice.total_amount&.to_s("F"))
      end
      invoice
    end

    private

    attr_reader :invoice, :actor, :comment
  end
end
