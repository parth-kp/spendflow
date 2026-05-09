class ApprovalRulePolicy < ApplicationPolicy
  def index? = finance_or_admin?
  def preview? = true
  def create? = admin?
  def update? = admin?
  def destroy? = admin?

  class Scope < Scope
    def resolve
      user.finance? || user.admin? ? scope.all : scope.none
    end
  end
end
