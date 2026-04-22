module Invoices
  class RunMatch
    def initialize(invoice, actor: nil)
      @invoice = invoice
      @actor = actor
    end

    def call
      invoice.with_lock do
        raise ArgumentError, "Invoice #{invoice.id} is #{invoice.status}" unless invoice.matchable?

        result = Matching::ThreeWayMatch.new(invoice).call
        by_id = result.lines.index_by { |l| l[:invoice_line_id] }
        invoice.lines.each do |line|
          r = by_id[line.id] || {}
          line.update!(purchase_order_line_id: r[:purchase_order_line_id], match_status: r[:status], match_notes: r[:notes] || [])
        end

        invoice.match_result = result.to_h
        result.matched? ? invoice.mark_matched! : invoice.flag_exception!

        failed = result.checks.reject { |c| c[:passed] }.map { |c| c[:name] } +
                 result.lines.reject { |l| l[:status] == "matched" }.map { |l| "line:#{l[:status]}" }
        invoice.audit!(:matched, actor: actor, status: result.status, purchase_order: invoice.purchase_order&.number,
                                 issues: failed.uniq)
      end

      notify_finance if invoice.exception?
      invoice
    end

    private

    attr_reader :invoice, :actor

    def notify_finance
      ids = User.active.where(role: %w[finance admin]).pluck(:id)
      return if ids.empty?

      NotifyUsersJob.perform_later(
        company_id: invoice.company_id, user_ids: ids, kind: "invoice_exception",
        title: "Invoice #{invoice.invoice_number || "##{invoice.id}"} needs review",
        body: "3-way match found issues against #{invoice.purchase_order&.number || 'no purchase order'}.",
        subject_gid: invoice.to_global_id.to_s
      )
    end
  end
end
