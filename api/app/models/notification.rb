class Notification < ApplicationRecord
  acts_as_tenant :company
  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  validates :kind, :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read!
    update!(read_at: Time.current) unless read_at
  end
end
