class AuditEventPolicy < ApplicationPolicy
  def index? = true

  class Scope < Scope
    def resolve
      user.finance? || user.admin? ? scope.all : scope.none
    end
  end
end
