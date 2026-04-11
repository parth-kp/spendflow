class SupplierPolicy < ApplicationPolicy
  def index? = true
  def show? = true
  def create? = finance_or_admin?
  def update? = finance_or_admin?
  def destroy? = admin?
end
