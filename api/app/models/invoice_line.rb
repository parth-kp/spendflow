class InvoiceLine < ApplicationRecord
  MATCH_STATUSES = %w[matched price_variance quantity_variance unmatched].freeze

  belongs_to :invoice, inverse_of: :lines
  belongs_to :purchase_order_line, optional: true

  validates :description, presence: true
  validates :quantity, :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :match_status, inclusion: { in: MATCH_STATUSES }, allow_nil: true

  before_validation do
    stale = persisted? && (quantity_changed? || unit_price_changed?) && !amount_changed?
    self.amount = stale ? computed_amount : effective_amount
  end

  def effective_amount
    amount.to_d.nonzero? || computed_amount
  end

  def computed_amount
    (quantity.to_d * unit_price.to_d).round(2)
  end
end
