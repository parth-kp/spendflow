module Procurement
  class IssuePurchaseOrder
    class Error < StandardError; end

    def initialize(requisition, actor:, supplier: nil, expected_on: nil)
      @requisition = requisition
      @actor = actor
      @supplier = supplier || requisition.supplier
      @expected_on = expected_on || requisition.needed_by
    end

    def call
      raise Error, "Requisition must be approved first" unless requisition.approved?
      raise Error, "Choose a supplier before issuing the PO" unless supplier

      po = nil
      requisition.with_lock do
        po = PurchaseOrder.create!(
          company: requisition.company, requisition: requisition, supplier: supplier, created_by: actor,
          currency: requisition.currency, expected_on: expected_on, issued_at: Time.current,
          lines: requisition.lines.each_with_index.map { |l, i| build_line(l, i + 1) }
        )
        po.recalculate_total
        po.save!
        requisition.mark_ordered!
        requisition.audit!(:converted_to_po, actor: actor, purchase_order: po.number)
        po.audit!(:issued, actor: actor, requisition: requisition.number, total: po.total_amount.to_s("F"))
      end

      NotifyUsersJob.perform_later(
        company_id: po.company_id, user_ids: [requisition.requester_id], kind: "po_issued",
        title: "#{po.number} issued to #{supplier.name}",
        body: "Your requisition #{requisition.number} is now purchase order #{po.number}.",
        subject_gid: po.to_global_id.to_s
      )
      po
    end

    private

    attr_reader :requisition, :actor, :supplier, :expected_on

    def build_line(req_line, line_no)
      PurchaseOrderLine.new(requisition_line: req_line, line_no: line_no, description: req_line.description,
                            unit: req_line.unit, quantity: req_line.quantity, unit_price: req_line.unit_price)
    end
  end
end
