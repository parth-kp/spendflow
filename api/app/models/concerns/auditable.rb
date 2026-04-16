module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_events, -> { order(:created_at, :id) }, as: :auditable
  end

  def audit!(action, actor: Current.user, **metadata)
    AuditEvent.create!(company_id: company_id, auditable: self, actor: actor, action: action.to_s, metadata: metadata)
  end
end
