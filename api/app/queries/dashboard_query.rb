class DashboardQuery
  def initialize(user)
    @user = user
  end

  def call
    data = {
      my_requisitions: Requisition.where(requester_id: user.id).group(:status).count,
      awaiting_my_approval: ApprovalInboxQuery.new(user).call.count
    }
    data.merge!(finance_metrics) if user.finance? || user.admin?
    data
  end

  private

  attr_reader :user

  def finance_metrics
    since = 90.days.ago
    {
      invoices_by_status: Invoice.group(:status).count,
      open_po_value: PurchaseOrder.where(status: %w[issued partially_received received]).sum(:total_amount).to_s("F"),
      payables_due_7d: Invoice.where(status: "approved", due_date: ..7.days.from_now.to_date).sum(:total_amount).to_s("F"),
      spend_by_department: Requisition.where(status: %w[approved ordered], approved_at: since..)
                                      .joins(:department).group("departments.name").sum(:total_amount)
                                      .transform_values { |v| v.to_s("F") },
      top_suppliers: PurchaseOrder.where(issued_at: since..).joins(:supplier).group("suppliers.name")
                                  .order(Arel.sql("SUM(purchase_orders.total_amount) DESC")).limit(5)
                                  .sum(:total_amount).map { |name, total| { name: name, total: total.to_s("F") } },
      avg_approval_hours: Requisition.where.not(approved_at: nil).where(approved_at: since..)
                                     .pick(Arel.sql("ROUND(AVG(EXTRACT(EPOCH FROM approved_at - submitted_at) / 3600)::numeric, 1)"))
                                     &.to_f
    }
  end
end
