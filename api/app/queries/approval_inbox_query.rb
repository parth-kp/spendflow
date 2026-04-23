# Requisitions whose *current* (lowest pending) approval step the user can act on.
# Mirrors ApprovalStep#actionable_by? in SQL so the inbox can be paginated.
class ApprovalInboxQuery
  def initialize(user, scope: Requisition.all)
    @user = user
    @scope = scope
  end

  def call
    steps = ApprovalStep.arel_table
    current = ApprovalStep.pending
                          .where(company_id: user.company_id)
                          .where(<<~SQL.squish)
                            NOT EXISTS (
                              SELECT 1 FROM approval_steps earlier
                              WHERE earlier.requisition_id = approval_steps.requisition_id
                                AND earlier.status = 'pending'
                                AND earlier.level < approval_steps.level
                            )
                          SQL
                          .where(eligible(steps))

    scope.pending_approval
         .where.not(requester_id: user.id)
         .where(id: current.select(:requisition_id))
  end

  private

  attr_reader :user, :scope

  def eligible(steps)
    return Arel.sql("TRUE") if user.admin?

    named = steps[:approver_id].eq(user.id)
    by_role =
      if user.manager?
        steps[:approver_role].eq("manager").and(
          steps[:requisition_id].in(Requisition.where(department_id: user.department_id).select(:id).arel)
        )
      elsif user.finance?
        steps[:approver_role].eq("finance")
      end

    by_role ? named.or(steps[:approver_id].eq(nil).and(by_role)) : named
  end
end
