# Requisitions whose current approval step the user can act on. Mirrors
# ApprovalStep#actionable_by? using the current_approver_* columns that
# Approvals::Workflow keeps in sync, so it is a single indexed lookup.
class ApprovalInboxQuery
  def initialize(user, scope: Requisition.all)
    @user = user
    @scope = scope
  end

  def call
    base = scope.pending_approval.where.not(requester_id: user.id)
    return base if user.admin?

    named = base.where(current_approver_id: user.id)
    by_role =
      if user.manager?
        base.where(current_approver_id: nil, current_approver_role: "manager", department_id: user.department_id)
      elsif user.finance?
        base.where(current_approver_id: nil, current_approver_role: "finance")
      end

    by_role ? named.or(by_role) : named
  end

  private

  attr_reader :user, :scope
end
