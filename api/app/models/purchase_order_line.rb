class PurchaseOrderLine < ApplicationRecord
  belongs_to :purchase_order, inverse_of: :lines
  belongs_to :requisition_line, optional: true

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :received_quantity, :invoiced_quantity, numericality: { greater_than_or_equal_to: 0 }

  def amount
    (quantity * unit_price).round(2)
  end

  def open_quantity
    [quantity - received_quantity, 0].max
  end

  def fully_received?
    received_quantity >= quantity
  end
end
