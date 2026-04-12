class Requisition < ApplicationRecord
  include AASM
  include Auditable

  acts_as_tenant :company
  belongs_to :requester, class_name: "User"
  belongs_to :department
  belongs_to :supplier, optional: true
  has_many :lines, class_name: "RequisitionLine", inverse_of: :requisition, dependent: :destroy
  has_many :approval_steps, -> { order(:level) }, dependent: :destroy

  accepts_nested_attributes_for :lines, allow_destroy: true

  validates :title, presence: true
  validates :number, presence: true
  validates_uniqueness_to_tenant :number
  validate :must_have_lines, if: -> { pending_approval? || submitted_at_changed? }

  before_validation :assign_number, on: :create
  before_validation :inherit_defaults, on: :create
  before_save :recalculate_total

  aasm column: :status, whiny_persistence: true do
    state :draft, initial: true
    state :pending_approval, :approved, :rejected, :cancelled, :ordered

    event :submit do
      transitions from: :draft, to: :pending_approval, after: -> { self.submitted_at = Time.current }
    end

    event :approve do
      transitions from: :pending_approval, to: :approved, after: -> { self.approved_at = Time.current }
    end

    event :reject do
      transitions from: :pending_approval, to: :rejected, after: -> { self.rejected_at = Time.current }
    end

    event :revise do
      transitions from: :rejected, to: :draft, after: -> { self.submitted_at = self.rejected_at = nil }
    end

    event :cancel do
      transitions from: %i[draft pending_approval], to: :cancelled
    end

    event :mark_ordered do
      transitions from: :approved, to: :ordered
    end
  end

  def editable?
    draft?
  end

  def current_step
    approval_steps.detect(&:pending?)
  end

  private

  def assign_number
    self.number ||= NumberSequence.next_for(company, "REQ") if company
  end

  def inherit_defaults
    self.department ||= requester&.department
    self.currency = company.currency if company
  end

  def recalculate_total
    self.total_amount = lines.reject(&:marked_for_destruction?).sum { |l| l.quantity.to_d * l.unit_price.to_d }.round(2)
  end

  def must_have_lines
    errors.add(:lines, "must include at least one item") if lines.reject(&:marked_for_destruction?).empty?
  end
end
