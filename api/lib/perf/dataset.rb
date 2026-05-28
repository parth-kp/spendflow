module Perf
  # Bulk-loads a realistic, skewed dataset with set-based SQL. One tenant owns
  # ~60% of the rows, as a large customer would on a shared database.
  class Dataset
    def initialize(companies:, requisitions:)
      @companies = Integer(companies)
      @requisitions = Integer(requisitions)
    end

    def generate!
      conn = ActiveRecord::Base.connection
      tables = %w[audit_events notifications invoice_lines invoices goods_receipt_lines goods_receipts
                  purchase_order_lines purchase_orders approval_steps requisition_lines requisitions approval_rules
                  suppliers users departments number_sequences companies]
      conn.execute("TRUNCATE #{tables.join(', ')} RESTART IDENTITY CASCADE")

      step("companies") { conn.execute(<<~SQL) }
        INSERT INTO companies (name, slug, currency, created_at, updated_at)
        SELECT 'Perf Co ' || i, 'perf-co-' || i, 'USD', now(), now() FROM generate_series(1, #{@companies}) i
      SQL

      step("departments") { conn.execute(<<~SQL) }
        INSERT INTO departments (company_id, name, code, created_at, updated_at)
        SELECT c, 'Dept ' || d, 'D' || d, now(), now()
        FROM generate_series(1, #{@companies}) c, generate_series(1, 12) d
      SQL

      step("users") { conn.execute(<<~SQL) }
        INSERT INTO users (company_id, department_id, name, email, password_digest, role, active, created_at, updated_at)
        SELECT c, (c - 1) * 12 + 1 + (u % 12), 'User ' || c || '-' || u, 'u' || c || '-' || u || '@perf.test', 'x',
               CASE WHEN u <= 12 THEN 'manager' WHEN u <= 16 THEN 'finance' WHEN u <= 18 THEN 'admin' ELSE 'employee' END,
               true, now(), now()
        FROM generate_series(1, #{@companies}) c, generate_series(1, 400) u
      SQL

      step("suppliers") { conn.execute(<<~SQL) }
        INSERT INTO suppliers (company_id, name, payment_terms_days, active, created_at, updated_at)
        SELECT c, 'Supplier ' || c || '-' || s, 30, true, now(), now()
        FROM generate_series(1, #{@companies}) c, generate_series(1, 300) s
      SQL

      step("approval_rules") { conn.execute(<<~SQL) }
        INSERT INTO approval_rules (company_id, name, level, min_amount, approver_role, created_at, updated_at)
        SELECT c, r.name, r.level, r.min_amount, r.role, now(), now()
        FROM generate_series(1, #{@companies}) c,
             (VALUES ('Manager', 1, 0, 'manager'), ('Finance', 2, 5000, 'finance'), ('Exec', 3, 50000, 'admin'))
               AS r(name, level, min_amount, role)
      SQL

      # company skew: first tenant gets ~60% of requisitions
      step("requisitions") { conn.execute(<<~SQL) }
        INSERT INTO requisitions (company_id, requester_id, department_id, supplier_id, number, title, status,
                                  total_amount, currency, submitted_at, approved_at, created_at, updated_at)
        SELECT co, (co - 1) * 400 + 1 + u, (co - 1) * 12 + 1 + (u % 12), (co - 1) * 300 + 1 + (i % 300),
               'REQ-' || lpad(i::text, 7, '0'),
               (ARRAY['Laptops', 'Office chairs', 'Cloud credits', 'Travel', 'Consulting', 'Paper', 'Monitors',
                      'Software licences', 'Freight', 'Catering'])[1 + i % 10] || ' batch ' || i,
               st, amt, 'USD',
               CASE WHEN st <> 'draft' THEN ts + interval '1 hour' END,
               CASE WHEN st IN ('approved', 'ordered') THEN ts + interval '1 day' END,
               ts, ts
        FROM (
          SELECT i,
                 CASE WHEN random() < 0.6 THEN 1 ELSE 2 + (i % #{[@companies - 1, 1].max}) END AS co,
                 (i::bigint * 7919) % 400 AS u,
                 (ARRAY['draft', 'pending_approval', 'approved', 'ordered', 'ordered', 'ordered', 'rejected', 'cancelled'])[1 + (i % 8)] AS st,
                 round((50 + random() * random() * 80000)::numeric, 2) AS amt,
                 now() - (random() * interval '730 days') AS ts
          FROM generate_series(1, #{@requisitions}) i
        ) s
      SQL

      step("requisition_lines") { conn.execute(<<~SQL) }
        INSERT INTO requisition_lines (requisition_id, description, quantity, unit, unit_price, line_total, created_at, updated_at)
        SELECT r.id, 'Item ' || n, 1, 'ea', round(r.total_amount / 2, 2), round(r.total_amount / 2, 2), r.created_at, r.created_at
        FROM requisitions r, generate_series(1, 2) n
      SQL

      step("approval_steps") { conn.execute(<<~SQL) }
        INSERT INTO approval_steps (company_id, requisition_id, level, approver_role, status, decided_at, created_at, updated_at)
        SELECT r.company_id, r.id, l.level, l.role,
               CASE
                 WHEN r.status IN ('approved', 'ordered') THEN 'approved'
                 WHEN r.status = 'rejected' THEN CASE WHEN l.level = 1 THEN 'rejected' ELSE 'skipped' END
                 WHEN r.status = 'pending_approval' THEN
                   CASE WHEN l.level = 1 AND r.id % 3 = 0 THEN 'approved' ELSE 'pending' END
                 ELSE 'skipped'
               END,
               r.submitted_at, r.submitted_at, r.submitted_at
        FROM requisitions r
        JOIN (VALUES (1, 'manager', 0), (2, 'finance', 5000), (3, 'admin', 50000)) AS l(level, role, min_amount)
          ON r.total_amount >= l.min_amount
        WHERE r.status <> 'draft'
      SQL

      step("purchase_orders") { conn.execute(<<~SQL) }
        INSERT INTO purchase_orders (company_id, requisition_id, supplier_id, created_by_id, number, status, total_amount,
                                     currency, issued_at, created_at, updated_at)
        SELECT r.company_id, r.id, r.supplier_id, r.requester_id, 'PO-' || lpad(r.id::text, 7, '0'),
               (ARRAY['issued', 'partially_received', 'received', 'received', 'closed'])[1 + r.id % 5],
               r.total_amount, 'USD', r.approved_at, r.approved_at, r.approved_at
        FROM requisitions r WHERE r.status = 'ordered'
      SQL

      step("invoices") { conn.execute(<<~SQL) }
        INSERT INTO invoices (company_id, supplier_id, purchase_order_id, uploaded_by_id, invoice_number, invoice_date,
                              due_date, currency, subtotal, tax_amount, total_amount, status, source, created_at, updated_at)
        SELECT p.company_id, p.supplier_id, p.id, p.created_by_id, 'INV-' || p.id, p.issued_at::date,
               p.issued_at::date + 30, 'USD', p.total_amount, 0, p.total_amount,
               (ARRAY['extracted', 'matched', 'exception', 'approved', 'approved', 'paid', 'paid', 'paid'])[1 + p.id % 8],
               'upload', p.issued_at + interval '5 days', p.issued_at + interval '5 days'
        FROM purchase_orders p WHERE p.status IN ('received', 'closed', 'partially_received')
      SQL

      step("audit_events") { conn.execute(<<~SQL) }
        INSERT INTO audit_events (company_id, actor_id, auditable_type, auditable_id, action, metadata, created_at)
        SELECT r.company_id, r.requester_id, 'Requisition', r.id, a.action, '{}'::jsonb, r.created_at + a.offs
        FROM requisitions r,
             (VALUES ('created', interval '0'), ('submitted', interval '1 hour'),
                     ('step_approved', interval '5 hours'), ('approved', interval '1 day')) AS a(action, offs)
      SQL

      step("notifications") { conn.execute(<<~SQL) }
        INSERT INTO notifications (company_id, user_id, kind, title, read_at, subject_type, subject_id, created_at, updated_at)
        SELECT r.company_id, r.requester_id, 'requisition_update', r.number || ' updated',
               CASE WHEN r.id % 4 = 0 THEN NULL ELSE r.created_at + interval '2 days' END,
               'Requisition', r.id, r.created_at, r.created_at
        FROM requisitions r
      SQL

      step("analyze") { conn.execute("ANALYZE") }
      counts = tables.reverse.to_h { |t| [t, conn.select_value("SELECT count(*) FROM #{t}")] }
      puts counts.map { |t, n| format("%-22s %10d", t, n) }
    end

    private

    def step(name)
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      puts format("  %-20s %6.1fs", name, Process.clock_gettime(Process::CLOCK_MONOTONIC) - t)
    end
  end
end
