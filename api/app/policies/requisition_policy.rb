class RequisitionPolicy < ApplicationPolicy
  def index? = true

  def show?
    owner? || finance_or_admin? || same_department_manager? || assigned_approver?
  end

  def create? = true
  def update? = owner? && record.editable?
  def destroy? = owner? && record.draft?
  def submit? = owner? && record.draft?
  def cancel? = (owner? || admin?) && (record.draft? || record.pending_approval?)
  def revise? = owner? && record.rejected?

  def decide?
    record.pending_approval? && record.current_step&.actionable_by?(user)
  end

  def convert? = finance_or_admin? && record.approved?

  private

  def owner? = record.requester_id == user.id
  def same_department_manager? = user.manager? && record.department_id == user.department_id
  def assigned_approver? = record.approval_steps.any? { |s| s.approver_id == user.id }

  class Scope < Scope
    def resolve
      return scope.all if user.finance? || user.admin?

      if user.manager?
        scope.where(requester_id: user.id).or(scope.where(department_id: user.department_id))
      else
        scope.where(requester_id: user.id)
      end
    end
  end
end
