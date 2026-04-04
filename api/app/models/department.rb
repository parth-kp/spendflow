class Department < ApplicationRecord
  acts_as_tenant :company

  has_many :users, dependent: :nullify

  validates :name, presence: true
  validates :code, presence: true, format: { with: /\A[A-Z0-9_]+\z/ }
  validates_uniqueness_to_tenant :code

  before_validation { self.code = code.to_s.upcase.strip.presence }
end
