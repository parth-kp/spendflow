class PurchaseOrder < ApplicationRecord
  include AASM
  include Auditable

  acts_as_tenant :company
  belongs_to :requisition, optional: true
  belongs_to :supplier
  belongs_to :created_by, class_name: "User"
  has_many :lines, -> { order(:line_no) }, class_name: "PurchaseOrderLine", inverse_of: :purchase_order,
                                            dependent: :destroy
  has_many :goods_receipts, dependent: :restrict_with_error

  validates_same_tenant :requisition, :supplier, :created_by
  validates :number, presence: true
  validates_uniqueness_to_tenant :number

  before_validation :assign_number, on: :create

  aasm column: :status, whiny_persistence: true do
    state :issued, initial: true
    state :partially_received, :received, :closed, :cancelled

    event :register_receipt do
      transitions from: %i[issued partially_received], to: :received, guard: :fully_received?
      transitions from: %i[issued partially_received], to: :partially_received
    end

    event :close do
      transitions from: %i[issued partially_received received], to: :closed, after: -> { self.closed_at = Time.current }
    end

    event :cancel do
      transitions from: :issued, to: :cancelled, guard: -> { lines.all? { |l| l.received_quantity.zero? } }
    end
  end

  def fully_received?
    lines.all?(&:fully_received?)
  end

  def recalculate_total
    self.total_amount = lines.sum(&:amount)
  end

  private

  def assign_number
    self.number ||= NumberSequence.next_for(company, "PO") if company
  end
end
