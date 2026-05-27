# Demo data. Every flow goes through the real services so the audit trail,
# approval steps and match results look like they would in production.
#
#   bin/rails db:seed            # idempotent: skips if demo companies exist
#   bin/rails db:seed:replant    # wipe and reseed

srand(42)

PASSWORD = "password123".freeze

ActiveJob::Base.queue_adapter = :inline
ActionMailer::Base.delivery_method = :test

def seed_company(name:, currency:, people:, suppliers:)
  company = Company.find_or_create_by!(name: name) { |c| c.currency = currency }
  return company if User.unscoped.exists?(company_id: company.id)

  ActsAsTenant.with_tenant(company) do
    depts = {
      "ENG" => Department.create!(name: "Engineering", code: "ENG"),
      "OPS" => Department.create!(name: "Operations", code: "OPS"),
      "MKT" => Department.create!(name: "Marketing", code: "MKT"),
      "FIN" => Department.create!(name: "Finance", code: "FIN")
    }

    users = people.to_h do |key, (full_name, role, dept)|
      [key, User.create!(name: full_name, email: "#{key}@#{company.slug}.test", password: PASSWORD, role: role,
                         department: depts[dept])]
    end

    ApprovalRule.create!(name: "Line manager", level: 1, min_amount: 0, approver_role: "manager")
    ApprovalRule.create!(name: "Finance review", level: 2, min_amount: 5_000, approver_role: "finance")
    ApprovalRule.create!(name: "Executive sign-off", level: 3, min_amount: 50_000, approver_role: "admin")
    ApprovalRule.create!(name: "Engineering finance review", level: 2, min_amount: 2_500, approver_role: "finance",
                         department: depts["ENG"])

    supplier_records = suppliers.map do |s_name, terms|
      Supplier.create!(name: s_name, email: "ap@#{s_name.parameterize}.test", payment_terms_days: terms,
                       tax_id: format("%02d-%07d", rand(10..99), rand(1_000_000..9_999_999)),
                       address: "#{rand(100..9999)} #{%w[Market Harbor Pine Oak Mill].sample} Street")
    end

    yield company, users, depts, supplier_records if block_given?
  end
  company
end

JUSTIFICATIONS = [
  "Replacing equipment that is out of warranty.",
  "Needed for the new starters joining next month.",
  "Agreed in the quarterly planning review.",
  "Current stock runs out in two weeks.",
  "Customer project requires this before go-live."
].freeze

def requisition(requester, title, supplier, lines, days_ago: 0)
  req = Requisition.create!(requester: requester, title: title, supplier: supplier,
                            justification: JUSTIFICATIONS.sample, needed_by: Date.current + rand(7..30),
                            lines_attributes: lines.map { |d, q, p| { description: d, quantity: q, unit_price: p } })
  req.update_columns(created_at: days_ago.days.ago)
  req.audit!(:created, actor: requester)
  req
end

def submit(req) = Approvals::Workflow.new(req, actor: req.requester).submit!

def approve_all(req)
  while req.reload.pending_approval?
    step = req.current_step
    approver = User.active.find { |u| step.actionable_by?(u) && !u.admin? } || User.active.find { |u| step.actionable_by?(u) }
    Approvals::Workflow.new(req, actor: approver).decide!(:approve, comment: ["Approved", "Within budget", "OK", nil].sample)
  end
  req
end

def issue(req, buyer) = Procurement::IssuePurchaseOrder.new(req, actor: buyer).call

def receive_all(po, receiver, fraction: 1)
  quantities = po.lines.to_h { |l| [l.id, (l.quantity * fraction).floor] }
  Procurement::ReceiveGoods.new(po, actor: receiver, quantities: quantities).call
end

def manual_invoice(po, uploader, number:, price_bump: 0, qty_bump: 0)
  inv = Invoice.create!(
    supplier: po.supplier, purchase_order: po, uploaded_by: uploader, source: "manual", invoice_number: number,
    invoice_date: Date.current - 3, due_date: Date.current + po.supplier.payment_terms_days, currency: po.currency,
    lines_attributes: po.lines.map do |l|
      { description: l.description, quantity: l.received_quantity + qty_bump, unit_price: l.unit_price + price_bump }
    end
  )
  inv.finish_extraction!
  Invoices::RunMatch.new(inv, actor: uploader).call
end

seed_company(
  name: "Acme Corp", currency: "USD",
  people: {
    "admin" => ["Avery Admin", "admin", "FIN"],
    "fiona" => ["Fiona Finance", "finance", "FIN"],
    "frank" => ["Frank Ledger", "finance", "FIN"],
    "maya" => ["Maya Manager", "manager", "ENG"],
    "omar" => ["Omar Ops", "manager", "OPS"],
    "mia" => ["Mia Marketing", "manager", "MKT"],
    "eli" => ["Eli Engineer", "employee", "ENG"],
    "olivia" => ["Olivia Operator", "employee", "OPS"],
    "marco" => ["Marco Media", "employee", "MKT"]
  },
  suppliers: [["Northwind Traders", 30], ["Contoso Hardware", 45], ["Fabrikam Office Supply", 30],
              ["Initech Cloud", 15], ["Umbrella Logistics", 60]]
) do |_company, u, _depts, s|
  northwind, contoso, fabrikam, initech, umbrella = s

  submit(requisition(u["eli"], "Laptop refresh for new hires", contoso,
                     [["MacBook Pro 14\" M4", 3, 2399], ["USB-C dock", 3, 249]], days_ago: 1))
  submit(requisition(u["olivia"], "Warehouse safety gear", umbrella,
                     [["Hi-vis vest", 40, 12.5], ["Steel toe boots", 20, 89]], days_ago: 2))
  submit(requisition(u["marco"], "Trade show booth", fabrikam,
                     [["Booth rental", 1, 18_000], ["Printed banners", 6, 450]], days_ago: 3))
  requisition(u["eli"], "Ergonomic chairs", fabrikam, [["Ergonomic chair", 4, 410]])

  rejected = submit(requisition(u["marco"], "Team offsite in Lisbon", nil, [["Venue & travel", 1, 42_000]], days_ago: 9))
  Approvals::Workflow.new(rejected, actor: u["mia"]).decide!(:reject, comment: "Not in this quarter's budget")

  paper = approve_all(submit(requisition(u["olivia"], "Office consumables Q4", northwind,
                                         [["A4 copy paper box", 10, 30], ["Laser toner cartridge black", 4, 90]],
                                         days_ago: 20)))
  paper_po = issue(paper, u["fiona"])
  receive_all(paper_po, u["olivia"])

  servers = approve_all(submit(requisition(u["eli"], "Staging cluster nodes", initech,
                                           [["Compute node 32 vCPU (annual)", 4, 3200], ["Managed Postgres (annual)", 1, 2400]],
                                           days_ago: 30)))
  servers_po = issue(servers, u["frank"])
  receive_all(servers_po, u["eli"])
  approved = manual_invoice(servers_po, u["fiona"], number: "INI-2026-0931")
  Invoices::Approve.new(approved, actor: u["frank"]).call

  monitors = approve_all(submit(requisition(u["eli"], "Monitors for design team", contoso,
                                            [["27\" 4K monitor", 6, 380], ["Monitor arm", 6, 95]], days_ago: 15)))
  monitors_po = issue(monitors, u["fiona"])
  receive_all(monitors_po, u["eli"], fraction: 0.5)
  manual_invoice(monitors_po, u["fiona"], number: "CH-88412", price_bump: 22, qty_bump: 3)

  freight = approve_all(submit(requisition(u["olivia"], "Pallet freight to Denver", umbrella,
                                           [["LTL freight", 1, 1850], ["Liftgate service", 1, 120]], days_ago: 12)))
  freight_po = issue(freight, u["frank"])
  receive_all(freight_po, u["olivia"])
  manual_invoice(freight_po, u["frank"], number: "UL-55102")

  approve_all(submit(requisition(u["marco"], "Social media tooling", initech,
                                 [["Scheduling tool seats (annual)", 5, 240]], days_ago: 6)))
end

seed_company(
  name: "Globex Industries", currency: "EUR",
  people: {
    "admin" => ["Gina Globex", "admin", "FIN"],
    "finance" => ["Hank Scorpio", "finance", "FIN"],
    "manager" => ["Lena Lead", "manager", "ENG"],
    "employee" => ["Sam Staff", "employee", "ENG"]
  },
  suppliers: [["Globex Parts GmbH", 30], ["Euro Office SA", 30]]
) do |_company, u, _depts, s|
  submit(requisition(u["employee"], "Soldering stations", s.first, [["Soldering station", 5, 310]]))
end

puts "Seeded: #{Company.count} companies, #{User.unscoped.count} users, #{Requisition.unscoped.count} requisitions, " \
     "#{PurchaseOrder.unscoped.count} POs, #{Invoice.unscoped.count} invoices"
puts "Log in as admin@acme-corp.test / #{PASSWORD} (also fiona@, maya@, eli@ ...)"
