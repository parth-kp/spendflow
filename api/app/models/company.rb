class Company < ApplicationRecord
  has_many :departments, dependent: :destroy
  has_many :users, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :currency, presence: true, length: { is: 3 }
  validates :price_tolerance_pct, :quantity_tolerance_pct,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug ||= name.to_s.parameterize
  end
end
