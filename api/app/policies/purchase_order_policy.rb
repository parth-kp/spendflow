class PurchaseOrderPolicy < ApplicationPolicy
  def index? = true
  def show? = finance_or_admin? || requester? || department_manager?
  def receive? = (finance_or_admin? || requester?) && (record.issued? || record.partially_received?)
  def close? = finance_or_admin? && record.may_close?
  def cancel? = finance_or_admin? && record.may_cancel?

  private

  def requester? = record.requisition&.requester_id == user.id
  def department_manager? = user.manager? && record.requisition&.department_id == user.department_id

  class Scope < Scope
    def resolve
      return scope.all if user.finance? || user.admin?

      reqs = Requisition.where(requester_id: user.id)
      reqs = reqs.or(Requisition.where(department_id: user.department_id)) if user.manager?
      scope.where(requisition_id: reqs.select(:id))
    end
  end
end
