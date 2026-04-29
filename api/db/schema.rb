# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_29_145752) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "approval_rules", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "department_id"
    t.bigint "approver_id"
    t.string "name", null: false
    t.integer "level", null: false
    t.decimal "min_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.string "approver_role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_approval_rules_on_approver_id"
    t.index ["company_id"], name: "index_approval_rules_on_company_id"
    t.index ["department_id"], name: "index_approval_rules_on_department_id"
  end

  create_table "approval_steps", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "requisition_id", null: false
    t.bigint "approval_rule_id"
    t.bigint "approver_id"
    t.bigint "decided_by_id"
    t.integer "level", null: false
    t.string "approver_role", null: false
    t.string "status", default: "pending", null: false
    t.text "comment"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_rule_id"], name: "index_approval_steps_on_approval_rule_id"
    t.index ["approver_id"], name: "index_approval_steps_on_approver_id"
    t.index ["company_id", "approver_role", "requisition_id"], name: "idx_approval_steps_pending_by_role", where: "((status)::text = 'pending'::text)"
    t.index ["company_id"], name: "index_approval_steps_on_company_id"
    t.index ["decided_by_id"], name: "index_approval_steps_on_decided_by_id"
    t.index ["requisition_id", "level"], name: "idx_approval_steps_pending_by_requisition", where: "((status)::text = 'pending'::text)"
    t.index ["requisition_id", "level"], name: "index_approval_steps_on_requisition_id_and_level", unique: true
    t.index ["requisition_id"], name: "index_approval_steps_on_requisition_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "actor_id"
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "action", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "request_id"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["company_id", "created_at", "id"], name: "idx_audit_events_company_created", order: { created_at: :desc, id: :desc }
    t.index ["company_id"], name: "index_audit_events_on_company_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "currency", default: "USD", null: false
    t.decimal "price_tolerance_pct", precision: 5, scale: 2, default: "2.0", null: false
    t.decimal "quantity_tolerance_pct", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_companies_on_slug", unique: true
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_departments_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_departments_on_company_id"
  end

  create_table "goods_receipt_lines", force: :cascade do |t|
    t.bigint "goods_receipt_id", null: false
    t.bigint "purchase_order_line_id", null: false
    t.decimal "quantity", precision: 12, scale: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goods_receipt_id"], name: "index_goods_receipt_lines_on_goods_receipt_id"
    t.index ["purchase_order_line_id"], name: "index_goods_receipt_lines_on_purchase_order_line_id"
  end

  create_table "goods_receipts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "purchase_order_id", null: false
    t.bigint "received_by_id", null: false
    t.string "number", null: false
    t.date "received_on", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "number"], name: "index_goods_receipts_on_company_id_and_number", unique: true
    t.index ["company_id"], name: "index_goods_receipts_on_company_id"
    t.index ["purchase_order_id"], name: "index_goods_receipts_on_purchase_order_id"
    t.index ["received_by_id"], name: "index_goods_receipts_on_received_by_id"
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "purchase_order_line_id"
    t.integer "position", default: 0, null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "unit_price", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "amount", precision: 14, scale: 2, default: "0.0", null: false
    t.string "match_status"
    t.jsonb "match_notes", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_lines_on_invoice_id"
    t.index ["purchase_order_line_id"], name: "index_invoice_lines_on_purchase_order_line_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "supplier_id"
    t.bigint "purchase_order_id"
    t.bigint "uploaded_by_id", null: false
    t.bigint "approved_by_id"
    t.string "invoice_number"
    t.date "invoice_date"
    t.date "due_date"
    t.string "currency"
    t.decimal "subtotal", precision: 14, scale: 2
    t.decimal "tax_amount", precision: 14, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 14, scale: 2
    t.string "status", default: "uploaded", null: false
    t.string "source", default: "upload", null: false
    t.jsonb "extraction", default: {}, null: false
    t.string "extraction_error"
    t.jsonb "match_result", default: {}, null: false
    t.decimal "match_confidence", precision: 5, scale: 4
    t.datetime "matched_at"
    t.datetime "approved_at"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_invoices_on_approved_by_id"
    t.index ["company_id", "status", "created_at"], name: "idx_invoices_company_status_created", order: { created_at: :desc }
    t.index ["company_id"], name: "index_invoices_on_company_id"
    t.index ["purchase_order_id"], name: "index_invoices_on_purchase_order_id"
    t.index ["supplier_id"], name: "index_invoices_on_supplier_id"
    t.index ["uploaded_by_id"], name: "index_invoices_on_uploaded_by_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_notifications_on_company_id"
    t.index ["subject_type", "subject_id"], name: "index_notifications_on_subject"
    t.index ["user_id"], name: "idx_notifications_unread", where: "(read_at IS NULL)"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "number_sequences", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "prefix", null: false
    t.bigint "value", default: 0, null: false
    t.index ["company_id", "prefix"], name: "index_number_sequences_on_company_id_and_prefix", unique: true
  end

  create_table "purchase_order_lines", force: :cascade do |t|
    t.bigint "purchase_order_id", null: false
    t.bigint "requisition_line_id"
    t.integer "line_no", null: false
    t.string "description", null: false
    t.string "unit", default: "ea", null: false
    t.decimal "quantity", precision: 12, scale: 3, null: false
    t.decimal "unit_price", precision: 14, scale: 2, null: false
    t.decimal "received_quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "invoiced_quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purchase_order_id", "line_no"], name: "index_purchase_order_lines_on_purchase_order_id_and_line_no", unique: true
    t.index ["purchase_order_id"], name: "index_purchase_order_lines_on_purchase_order_id"
    t.index ["requisition_line_id"], name: "index_purchase_order_lines_on_requisition_line_id"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "requisition_id"
    t.bigint "supplier_id", null: false
    t.bigint "created_by_id", null: false
    t.string "number", null: false
    t.string "status", default: "issued", null: false
    t.decimal "total_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.string "currency", null: false
    t.date "expected_on"
    t.datetime "issued_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "number"], name: "index_purchase_orders_on_company_id_and_number", unique: true
    t.index ["company_id"], name: "index_purchase_orders_on_company_id"
    t.index ["created_by_id"], name: "index_purchase_orders_on_created_by_id"
    t.index ["requisition_id"], name: "index_purchase_orders_on_requisition_id", unique: true
    t.index ["supplier_id", "status"], name: "idx_purchase_orders_supplier_status"
    t.index ["supplier_id"], name: "index_purchase_orders_on_supplier_id"
  end

  create_table "requisition_lines", force: :cascade do |t|
    t.bigint "requisition_id", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 12, scale: 3, null: false
    t.string "unit", default: "ea", null: false
    t.decimal "unit_price", precision: 14, scale: 2, null: false
    t.decimal "line_total", precision: 14, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requisition_id"], name: "index_requisition_lines_on_requisition_id"
  end

  create_table "requisitions", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "requester_id", null: false
    t.bigint "department_id", null: false
    t.bigint "supplier_id"
    t.string "number", null: false
    t.string "title", null: false
    t.text "justification"
    t.string "status", default: "draft", null: false
    t.decimal "total_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.string "currency", default: "USD", null: false
    t.date "needed_by"
    t.datetime "submitted_at"
    t.datetime "approved_at"
    t.datetime "rejected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "approved_at"], name: "idx_requisitions_approved_spend", where: "((status)::text = ANY ((ARRAY['approved'::character varying, 'ordered'::character varying])::text[]))", include: ["department_id", "total_amount"]
    t.index ["company_id", "number"], name: "index_requisitions_on_company_id_and_number", unique: true
    t.index ["company_id", "status", "created_at"], name: "idx_requisitions_company_status_created", order: { created_at: :desc }
    t.index ["company_id", "submitted_at"], name: "idx_requisitions_pending_submitted", where: "((status)::text = 'pending_approval'::text)"
    t.index ["company_id"], name: "index_requisitions_on_company_id"
    t.index ["department_id", "created_at"], name: "idx_requisitions_department_created", order: { created_at: :desc }
    t.index ["department_id"], name: "index_requisitions_on_department_id"
    t.index ["number"], name: "idx_requisitions_number_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["requester_id", "created_at"], name: "idx_requisitions_requester_created", order: { created_at: :desc }
    t.index ["requester_id"], name: "index_requisitions_on_requester_id"
    t.index ["supplier_id"], name: "index_requisitions_on_supplier_id"
    t.index ["title"], name: "idx_requisitions_title_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "suppliers", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "tax_id"
    t.string "address"
    t.integer "payment_terms_days", default: 30, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_suppliers_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_suppliers_on_company_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "department_id"
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "employee", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["department_id"], name: "index_users_on_department_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "approval_rules", "companies"
  add_foreign_key "approval_rules", "departments"
  add_foreign_key "approval_rules", "users", column: "approver_id"
  add_foreign_key "approval_steps", "approval_rules", on_delete: :nullify
  add_foreign_key "approval_steps", "companies"
  add_foreign_key "approval_steps", "requisitions"
  add_foreign_key "approval_steps", "users", column: "approver_id"
  add_foreign_key "approval_steps", "users", column: "decided_by_id"
  add_foreign_key "audit_events", "companies"
  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "departments", "companies"
  add_foreign_key "goods_receipt_lines", "goods_receipts", on_delete: :cascade
  add_foreign_key "goods_receipt_lines", "purchase_order_lines"
  add_foreign_key "goods_receipts", "companies"
  add_foreign_key "goods_receipts", "purchase_orders"
  add_foreign_key "goods_receipts", "users", column: "received_by_id"
  add_foreign_key "invoice_lines", "invoices", on_delete: :cascade
  add_foreign_key "invoice_lines", "purchase_order_lines", on_delete: :nullify
  add_foreign_key "invoices", "companies"
  add_foreign_key "invoices", "purchase_orders"
  add_foreign_key "invoices", "suppliers"
  add_foreign_key "invoices", "users", column: "approved_by_id"
  add_foreign_key "invoices", "users", column: "uploaded_by_id"
  add_foreign_key "notifications", "companies"
  add_foreign_key "notifications", "users"
  add_foreign_key "number_sequences", "companies"
  add_foreign_key "purchase_order_lines", "purchase_orders", on_delete: :cascade
  add_foreign_key "purchase_order_lines", "requisition_lines", on_delete: :nullify
  add_foreign_key "purchase_orders", "companies"
  add_foreign_key "purchase_orders", "requisitions"
  add_foreign_key "purchase_orders", "suppliers"
  add_foreign_key "purchase_orders", "users", column: "created_by_id"
  add_foreign_key "requisition_lines", "requisitions", on_delete: :cascade
  add_foreign_key "requisitions", "companies"
  add_foreign_key "requisitions", "departments"
  add_foreign_key "requisitions", "suppliers"
  add_foreign_key "requisitions", "users", column: "requester_id"
  add_foreign_key "suppliers", "companies"
  add_foreign_key "users", "companies"
  add_foreign_key "users", "departments"
end
