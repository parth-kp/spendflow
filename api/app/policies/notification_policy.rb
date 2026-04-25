class NotificationPolicy < ApplicationPolicy
  def index? = true
  def update? = record.user_id == user.id

  class Scope < Scope
    def resolve = scope.where(user_id: user.id)
  end
end
