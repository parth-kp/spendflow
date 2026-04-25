module Api
  module V1
    class AuditEventsController < ApplicationController
      AUDITABLE_TYPES = %w[Requisition PurchaseOrder Invoice].freeze

      def index
        if params[:auditable_type].present?
          type = AUDITABLE_TYPES.find { |t| t == params[:auditable_type] } or raise ActiveRecord::RecordNotFound
          record = type.constantize.find(params.require(:auditable_id))
          authorize record, :show?
          scope = record.audit_events
          skip_policy_scope
        else
          scope = policy_scope(AuditEvent).order(created_at: :desc, id: :desc)
          scope = scope.where(action: params[:action_name]) if params[:action_name].present?
          scope = scope.where(actor_id: params[:actor_id]) if params[:actor_id].present?
          scope = scope.where(auditable_type: params[:type]) if params[:type].present?
        end

        events = paginate(scope.includes(:actor, :auditable))
        render json: events.map { |e| serialize(e) }
      end

      private

      def serialize(e)
        {
          id: e.id, action: e.action, metadata: e.metadata, created_at: e.created_at, ip_address: e.ip_address,
          actor: e.actor&.slice(:id, :name, :role),
          auditable: { type: e.auditable_type, id: e.auditable_id, label: label(e.auditable) }
        }
      end

      def label(record)
        case record
        when Requisition, PurchaseOrder then record.number
        when Invoice then record.invoice_number.presence || "Invoice ##{record.id}"
        end
      end
    end
  end
end
