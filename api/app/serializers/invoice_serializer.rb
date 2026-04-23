class InvoiceSerializer < BaseSerializer
  def as_json(*)
    data = {
      id: object.id,
      invoice_number: object.invoice_number,
      status: object.status,
      source: object.source,
      invoice_date: object.invoice_date,
      due_date: object.due_date,
      currency: object.currency,
      subtotal: money(object.subtotal),
      tax_amount: money(object.tax_amount),
      total_amount: money(object.total_amount),
      match_confidence: object.match_confidence&.to_f,
      supplier: object.supplier && { id: object.supplier.id, name: object.supplier.name },
      purchase_order: object.purchase_order && { id: object.purchase_order.id, number: object.purchase_order.number },
      created_at: object.created_at
    }
    options[:detail] ? data.merge(detail) : data
  end

  private

  def detail
    {
      extraction: object.extraction,
      extraction_error: object.extraction_error,
      match_result: object.match_result,
      document: object.document.attached? && {
        filename: object.document.filename.to_s, content_type: object.document.content_type,
        byte_size: object.document.byte_size
      },
      uploaded_by: object.uploaded_by.slice(:id, :name),
      approved_by: object.approved_by&.slice(:id, :name),
      approved_at: object.approved_at,
      paid_at: object.paid_at,
      lines: object.lines.map do |l|
        { id: l.id, position: l.position, description: l.description, quantity: l.quantity.to_s("F"),
          unit_price: money(l.unit_price), amount: money(l.amount), purchase_order_line_id: l.purchase_order_line_id,
          match_status: l.match_status, match_notes: l.match_notes }
      end,
      permissions: options[:permissions]
    }
  end
end
