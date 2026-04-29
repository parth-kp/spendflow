class AddQueryIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    enable_extension "pg_trgm"

    # Status-filtered lists sorted newest first (finance queues)
    add_index :requisitions, [:company_id, :status, :created_at], order: { created_at: :desc },
              algorithm: :concurrently, name: "idx_requisitions_company_status_created"
    add_index :invoices, [:company_id, :status, :created_at], order: { created_at: :desc },
              algorithm: :concurrently, name: "idx_invoices_company_status_created"

    # Manager list: requester OR department, newest first
    add_index :requisitions, [:department_id, :created_at], order: { created_at: :desc },
              algorithm: :concurrently, name: "idx_requisitions_department_created"
    add_index :requisitions, [:requester_id, :created_at], order: { created_at: :desc },
              algorithm: :concurrently, name: "idx_requisitions_requester_created"

    # Free-text search on title / number
    add_index :requisitions, :title, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently,
              name: "idx_requisitions_title_trgm"
    add_index :requisitions, :number, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently,
              name: "idx_requisitions_number_trgm"

    # Approval inbox: only pending steps matter, and they are a small slice
    add_index :approval_steps, [:requisition_id, :level], where: "status = 'pending'",
              algorithm: :concurrently, name: "idx_approval_steps_pending_by_requisition"
    add_index :approval_steps, [:company_id, :approver_role, :requisition_id], where: "status = 'pending'",
              algorithm: :concurrently, name: "idx_approval_steps_pending_by_role"
    add_index :requisitions, [:company_id, :submitted_at], where: "status = 'pending_approval'",
              algorithm: :concurrently, name: "idx_requisitions_pending_submitted"

    # Company-wide audit log, newest first
    add_index :audit_events, [:company_id, :created_at, :id], order: { created_at: :desc, id: :desc },
              algorithm: :concurrently, name: "idx_audit_events_company_created"

    # Dashboard spend: approved spend in a time window
    add_index :requisitions, [:company_id, :approved_at], where: "status IN ('approved', 'ordered')",
              include: %i[department_id total_amount], algorithm: :concurrently,
              name: "idx_requisitions_approved_spend"

    # Unread badge
    add_index :notifications, :user_id, where: "read_at IS NULL", algorithm: :concurrently,
              name: "idx_notifications_unread"

    # PO finder: open POs per supplier
    add_index :purchase_orders, [:supplier_id, :status], algorithm: :concurrently,
              name: "idx_purchase_orders_supplier_status"
  end
end
