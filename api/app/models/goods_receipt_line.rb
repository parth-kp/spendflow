class GoodsReceiptLine < ApplicationRecord
  belongs_to :goods_receipt, inverse_of: :lines
  belongs_to :purchase_order_line

  validates :quantity, numericality: { greater_than: 0 }
  validate :line_belongs_to_po

  private

  def line_belongs_to_po
    return if purchase_order_line.nil? || goods_receipt.nil?
    return if purchase_order_line.purchase_order_id == goods_receipt.purchase_order_id

    errors.add(:purchase_order_line, "is not on this purchase order")
  end
end
