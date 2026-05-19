class Invoice < ApplicationRecord
  include AASM
  include Auditable

  ALLOWED_CONTENT_TYPES = %w[application/pdf image/png image/jpeg image/webp text/plain].freeze
  MAX_FILE_SIZE = 10.megabytes

  acts_as_tenant :company
  belongs_to :supplier, optional: true
  belongs_to :purchase_order, optional: true
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :lines, -> { order(:position) }, class_name: "InvoiceLine", inverse_of: :invoice, dependent: :destroy
  has_one_attached :document

  accepts_nested_attributes_for :lines, allow_destroy: true

  validates_same_tenant :supplier, :purchase_order, :uploaded_by
  validates :source, inclusion: { in: %w[upload manual] }
  validate :document_is_acceptable

  before_save :recalculate_totals, if: -> { lines.any? }

  aasm column: :status, whiny_persistence: true do
    state :uploaded, initial: true
    state :processing, :extraction_failed, :extracted, :matched, :exception, :approved, :rejected, :paid

    event :start_processing do
      transitions from: %i[uploaded extraction_failed], to: :processing
    end

    event :fail_extraction do
      transitions from: :processing, to: :extraction_failed
    end

    event :finish_extraction do
      transitions from: %i[processing uploaded], to: :extracted
    end

    event :mark_matched do
      transitions from: %i[extracted matched exception], to: :matched, after: -> { self.matched_at = Time.current }
    end

    event :flag_exception do
      transitions from: %i[extracted matched exception], to: :exception
    end

    event :approve do
      transitions from: %i[matched exception], to: :approved, after: -> { self.approved_at = Time.current }
    end

    event :reject do
      transitions from: %i[extracted matched exception extraction_failed], to: :rejected
    end

    event :mark_paid do
      transitions from: :approved, to: :paid, after: -> { self.paid_at = Time.current }
    end
  end

  # Duplicates are stored and flagged rather than refused, so a re-sent or
  # re-scanned invoice still shows up for review instead of failing silently.
  def duplicate_of
    return if invoice_number.blank? || supplier_id.nil?

    earlier = persisted? ? Invoice.where(id: ...id) : Invoice.all
    earlier.where(supplier_id: supplier_id).where.not(status: "rejected")
           .where("lower(invoice_number) = ?", invoice_number.downcase).order(:id).first
  end

  def matchable?
    extracted? || matched? || exception?
  end

  def recalculate_totals
    self.subtotal = lines.reject(&:marked_for_destruction?).sum(&:effective_amount)
    self.total_amount = subtotal + tax_amount.to_d
  end

  private

  def document_is_acceptable
    return unless document.attached?

    errors.add(:document, "must be a PDF, image or text file") unless ALLOWED_CONTENT_TYPES.include?(document.blob.content_type)
    errors.add(:document, "must be smaller than 10 MB") if document.blob.byte_size > MAX_FILE_SIZE
  end
end
