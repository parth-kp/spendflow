class RequisitionLine < ApplicationRecord
  belongs_to :requisition, inverse_of: :lines

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  before_validation { self.line_total = (quantity.to_d * unit_price.to_d).round(2) }
end
