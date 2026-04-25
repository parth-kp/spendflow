class UserPolicy < ApplicationPolicy
  def index? = true
  def show? = true
  def create? = admin?
  def update? = admin?

  def permitted_attributes
    admin? ? %i[name email role department_id active password] : []
  end
end
