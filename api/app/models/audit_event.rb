class AuditEvent < ApplicationRecord
  acts_as_tenant :company
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true

  validates :action, presence: true

  before_validation on: :create do
    self.actor ||= Current.user
    self.request_id ||= Current.request_id
    self.ip_address ||= Current.ip_address
  end

  def readonly?
    persisted?
  end

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Audit events are append-only" }
end
