class RequisitionSerializer < BaseSerializer
  def as_json(*)
    data = {
      id: object.id,
      number: object.number,
      title: object.title,
      status: object.status,
      total_amount: money(object.total_amount),
      currency: object.currency,
      needed_by: object.needed_by,
      submitted_at: object.submitted_at,
      approved_at: object.approved_at,
      created_at: object.created_at,
      requester: { id: object.requester.id, name: object.requester.name },
      department: { id: object.department.id, name: object.department.name },
      supplier: object.supplier && { id: object.supplier.id, name: object.supplier.name }
    }
    options[:detail] ? data.merge(detail) : data
  end

  private

  def detail
    {
      justification: object.justification,
      supplier_id: object.supplier_id,
      lines: object.lines.map do |l|
        { id: l.id, description: l.description, quantity: l.quantity.to_s("F"), unit: l.unit,
          unit_price: money(l.unit_price), line_total: money(l.line_total) }
      end,
      approval_steps: object.approval_steps.map do |s|
        { id: s.id, level: s.level, approver_role: s.approver_role, status: s.status,
          approver: s.approver&.slice(:id, :name), decided_by: s.decided_by&.slice(:id, :name),
          decided_at: s.decided_at, comment: s.comment }
      end,
      purchase_order: options[:purchase_order],
      permissions: options[:permissions]
    }
  end
end
