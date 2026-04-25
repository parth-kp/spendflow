class DepartmentPolicy < ApplicationPolicy
  def index? = true
  def create? = admin?
  def update? = admin?
  def destroy? = admin? && record.users.none?
end
