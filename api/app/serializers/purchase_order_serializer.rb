class PurchaseOrderSerializer < BaseSerializer
  def as_json(*)
    data = {
      id: object.id,
      number: object.number,
      status: object.status,
      total_amount: money(object.total_amount),
      currency: object.currency,
      expected_on: object.expected_on,
      issued_at: object.issued_at,
      supplier: { id: object.supplier.id, name: object.supplier.name },
      requisition: object.requisition && { id: object.requisition.id, number: object.requisition.number,
                                           title: object.requisition.title }
    }
    options[:detail] ? data.merge(detail) : data
  end

  private

  def detail
    {
      lines: object.lines.map do |l|
        { id: l.id, line_no: l.line_no, description: l.description, unit: l.unit,
          quantity: l.quantity.to_s("F"), unit_price: money(l.unit_price), amount: money(l.amount),
          received_quantity: l.received_quantity.to_s("F"), invoiced_quantity: l.invoiced_quantity.to_s("F") }
      end,
      receipts: object.goods_receipts.sort_by(&:created_at).map do |r|
        { id: r.id, number: r.number, received_on: r.received_on, notes: r.notes,
          received_by: r.received_by.slice(:id, :name),
          lines: r.lines.map { |gl| { purchase_order_line_id: gl.purchase_order_line_id, quantity: gl.quantity.to_s("F") } } }
      end,
      permissions: options[:permissions]
    }
  end
end
