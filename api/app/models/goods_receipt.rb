class GoodsReceipt < ApplicationRecord
  include Auditable

  acts_as_tenant :company
  belongs_to :purchase_order
  belongs_to :received_by, class_name: "User"
  has_many :lines, class_name: "GoodsReceiptLine", inverse_of: :goods_receipt, dependent: :destroy

  validates_same_tenant :purchase_order, :received_by
  validates :received_on, presence: true
  validate :must_have_lines

  before_validation :assign_number, on: :create

  private

  def assign_number
    self.number ||= NumberSequence.next_for(company, "GRN") if company
  end

  def must_have_lines
    errors.add(:lines, "must include at least one received item") if lines.empty?
  end
end
