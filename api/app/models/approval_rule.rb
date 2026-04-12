class ApprovalRule < ApplicationRecord
  APPROVER_ROLES = %w[manager finance admin].freeze

  acts_as_tenant :company
  belongs_to :department, optional: true
  belongs_to :approver, class_name: "User", optional: true

  validates :name, presence: true
  validates :level, numericality: { only_integer: true, in: 1..10 }
  validates :min_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :approver_role, inclusion: { in: APPROVER_ROLES }
  validate :approver_has_role

  # Rules for a level apply once the amount reaches min_amount. When both a
  # department-specific and a company-wide rule exist for the same level, the
  # department-specific one wins.
  def self.chain_for(department:, amount:)
    where(department_id: [nil, department&.id])
      .where(min_amount: ..amount)
      .order(:level, Arel.sql("department_id IS NULL"), min_amount: :desc)
      .group_by(&:level)
      .map { |_level, rules| rules.first }
  end

  private

  def approver_has_role
    return if approver.nil? || approver.approver?

    errors.add(:approver, "must be a manager, finance or admin user")
  end
end
