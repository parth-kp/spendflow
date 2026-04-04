class User < ApplicationRecord
  ROLES = %w[employee manager finance admin].freeze

  acts_as_tenant :company
  belongs_to :department, optional: true

  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :email_unique_globally

  before_validation { self.email = email.to_s.strip.downcase }

  scope :active, -> { where(active: true) }

  ROLES.each do |r|
    define_method(:"#{r}?") { role == r }
  end

  def approver?
    manager? || finance? || admin?
  end

  private

  def email_unique_globally
    scope = User.unscoped.where("lower(email) = ?", email)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:email, :taken) if scope.exists?
  end
end
