class Supplier < ApplicationRecord
  acts_as_tenant :company

  validates :name, presence: true
  validates_uniqueness_to_tenant :name, case_sensitive: false
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :payment_terms_days, numericality: { only_integer: true, in: 0..180 }

  scope :active, -> { where(active: true) }
  scope :search, ->(q) { where("suppliers.name ILIKE ?", "%#{sanitize_sql_like(q)}%") if q.present? }
end
