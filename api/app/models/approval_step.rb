class ApprovalStep < ApplicationRecord
  STATUSES = %w[pending approved rejected skipped].freeze

  acts_as_tenant :company
  belongs_to :requisition
  belongs_to :approval_rule, optional: true
  belongs_to :approver, class_name: "User", optional: true
  belongs_to :decided_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :level, presence: true

  STATUSES.each do |s|
    define_method(:"#{s}?") { status == s }
    scope s, -> { where(status: s) }
  end

  def actionable_by?(user)
    return false unless pending?
    return false if user.id == requisition.requester_id
    return true if user.admin?
    return user.id == approver_id if approver_id

    case approver_role
    when "manager" then user.manager? && user.department_id == requisition.department_id
    when "finance" then user.finance?
    else false
    end
  end
end
