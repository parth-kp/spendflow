class InvoicePolicy < ApplicationPolicy
  def index? = finance_or_admin?
  def show? = finance_or_admin?
  def create? = finance_or_admin?
  def document? = show?
  def update? = finance_or_admin? && (record.extracted? || record.matched? || record.exception? || record.extraction_failed?)
  def rematch? = finance_or_admin? && record.matchable?
  def reprocess? = finance_or_admin? && (record.extraction_failed? || record.uploaded?) && record.document.attached?
  def approve? = finance_or_admin? && record.may_approve? && record.uploaded_by_id != user.id
  def reject? = finance_or_admin? && record.may_reject?
  def pay? = finance_or_admin? && record.approved?

  class Scope < Scope
    def resolve
      user.finance? || user.admin? ? scope.all : scope.none
    end
  end
end
