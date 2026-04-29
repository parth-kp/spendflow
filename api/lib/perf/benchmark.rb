module Perf
  # Runs the app's real query objects/relations under EXPLAIN ANALYZE against
  # the perf database and records median execution time per query.
  class Benchmark
    RUNS = 7

    def initialize(label:)
      @label = label
      @conn = ActiveRecord::Base.connection
    end

    def run!
      company = Company.find_by!(slug: "perf-co-1")
      results = ActsAsTenant.with_tenant(company) { queries(company).map { |name, rel| measure(name, rel) } }

      dir = Rails.root.join("../docs/perf")
      FileUtils.mkdir_p(dir)
      File.write(dir.join("#{@label}.json"), JSON.pretty_generate(
        label: @label, measured_at: Time.current.iso8601, postgres: conn.select_value("SHOW server_version"),
        rows: { requisitions: Requisition.unscoped.count, approval_steps: ApprovalStep.unscoped.count,
                audit_events: AuditEvent.unscoped.count, notifications: Notification.unscoped.count,
                invoices: Invoice.unscoped.count },
        results: results
      ))

      puts format("%-34s %10s %10s  %s", "query", "median ms", "max ms", "plan")
      results.each { |r| puts format("%-34s %10.2f %10.2f  %s", r[:name], r[:median_ms], r[:max_ms], r[:plan]) }
    end

    private

    attr_reader :conn

    def queries(company)
      employee = User.where(role: "employee").joins(:requisitions_as_requester).group(:id).order(Arel.sql("count(*) DESC")).first
      manager = User.find_by!(role: "manager", department_id: employee.department_id)
      finance = User.find_by!(role: "finance")
      req = Requisition.where(requester_id: employee.id).order(:id).last
      supplier = req.supplier
      page = ->(scope) { scope.limit(25).offset(0) }

      {
        "requisitions: my list" => page.(RequisitionPolicy::Scope.new(employee, Requisition).resolve
                                      .where(requester_id: employee.id).order(created_at: :desc)),
        "requisitions: my list count" => RequisitionPolicy::Scope.new(employee, Requisition).resolve
                                           .where(requester_id: employee.id).select("count(*)"),
        "requisitions: manager list" => page.(RequisitionPolicy::Scope.new(manager, Requisition).resolve.order(created_at: :desc)),
        "requisitions: pending (finance)" => page.(Requisition.where(status: "pending_approval").order(created_at: :desc)),
        "requisitions: search title" => page.(Requisition.where("requisitions.title ILIKE :q OR requisitions.number ILIKE :q",
                                                                q: "%monitors batch 12345%").order(created_at: :desc)),
        "approval inbox: manager" => page.(ApprovalInboxQuery.new(manager).call.order(:submitted_at)),
        "approval inbox: finance" => page.(ApprovalInboxQuery.new(finance).call.order(:submitted_at)),
        "approval inbox: finance count" => ApprovalInboxQuery.new(finance).call.select("count(*)"),
        "audit trail: one record" => req.audit_events,
        "audit log: company page" => page.(AuditEvent.order(created_at: :desc, id: :desc)),
        "notifications: unread count" => Notification.where(user_id: employee.id).unread.select("count(*)"),
        "notifications: list" => page.(Notification.where(user_id: employee.id).recent),
        "invoices: exceptions" => page.(Invoice.where(status: %w[exception]).order(created_at: :desc)),
        "invoices: exceptions count" => Invoice.where(status: %w[exception]).select("count(*)"),
        "dashboard: spend by department" => Requisition.where(status: %w[approved ordered], approved_at: 90.days.ago..)
                                                       .joins(:department).group("departments.name")
                                                       .select("departments.name, sum(total_amount)"),
        "po finder: supplier candidates" => Matching::PurchaseOrderFinder.new(po_number: nil, supplier: supplier, total: 1234)
                                                                         .candidates
      }
    end

    def measure(name, relation)
      sql = relation.to_sql
      conn.select_all(sql) # warm cache
      timings = []
      plan = nil
      RUNS.times do
        out = JSON.parse(conn.select_value("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) #{sql}")).first
        timings << out["Execution Time"] + out["Planning Time"]
        plan ||= out["Plan"]
      end
      timings.sort!
      { name: name, median_ms: timings[RUNS / 2].round(2), max_ms: timings.last.round(2),
        plan: summarize(plan), sql: sql }
    end

    def summarize(node, acc = [])
      label = node["Node Type"]
      label += " on #{node['Relation Name']}" if node["Relation Name"]
      label += " (#{node['Index Name']})" if node["Index Name"]
      acc << label if label.match?(/Scan|Sort/)
      Array(node["Plans"]).each { |child| summarize(child, acc) }
      acc.uniq.first(4).join(" → ")
    end
  end
end
