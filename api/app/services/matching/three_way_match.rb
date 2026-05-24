module Matching
  # Compares an invoice against its purchase order (what was agreed) and the
  # goods receipts on that PO (what actually arrived).
  #
  #   price:    invoice unit price within the company's price tolerance of the PO price
  #   quantity: invoice qty <= received qty not yet invoiced (+ quantity tolerance)
  #   header:   same supplier and currency as the PO
  class ThreeWayMatch
    Result = Struct.new(:status, :checks, :lines, :purchase_order_id, keyword_init: true) do
      def matched? = status == "matched"

      def to_h
        { status: status, purchase_order_id: purchase_order_id, checks: checks, lines: lines }
      end
    end

    def initialize(invoice)
      @invoice = invoice
      @po = invoice.purchase_order
      @company = invoice.company
    end

    def call
      return no_po_result unless po

      checks = [duplicate_check] + header_checks
      pairs = LinePairer.new(invoice.lines.to_a, po.lines.to_a).call
      line_results = invoice.lines.map { |line| evaluate_line(line, pairs[line]) }

      checks << total_check(line_results)
      ok = checks.all? { |c| c[:passed] } && line_results.all? { |l| l[:status] == "matched" }

      Result.new(status: ok ? "matched" : "exception", checks: checks, lines: line_results, purchase_order_id: po.id)
    end

    private

    attr_reader :invoice, :po, :company

    def no_po_result
      Result.new(status: "exception", purchase_order_id: nil, lines: [],
                 checks: [duplicate_check,
                          { name: "purchase_order", passed: false, message: "No purchase order linked to this invoice" }])
    end

    def duplicate_check
      original = invoice.duplicate_of
      check("duplicate", original.nil?,
            "Same supplier and invoice number as invoice ##{original&.id} (#{original&.status&.humanize&.downcase})")
    end

    def header_checks
      [
        check("supplier", invoice.supplier_id.nil? || invoice.supplier_id == po.supplier_id,
              "Invoice supplier differs from PO supplier #{po.supplier.name}"),
        check("currency", invoice.currency.blank? || invoice.currency == po.currency,
              "Invoice currency #{invoice.currency} differs from PO currency #{po.currency}"),
        check("po_status", !po.cancelled?, "#{po.number} is cancelled")
      ]
    end

    def total_check(line_results)
      billed = invoice.lines.sum(&:effective_amount)
      expected = line_results.sum { |l| l[:expected_amount].to_d }
      tolerance = expected * price_tolerance
      check("total", (billed - expected).abs <= [tolerance, 0.01].max,
            "Invoice lines total #{money(billed)} vs #{money(expected)} expected from PO prices and received quantities")
    end

    def evaluate_line(line, po_line)
      base = { invoice_line_id: line.id, description: line.description,
               quantity: fmt(line.quantity), unit_price: fmt(line.unit_price) }
      unless po_line
        return base.merge(status: "unmatched", purchase_order_line_id: nil, expected_amount: "0",
                          notes: ["No matching line on #{po.number}"])
      end

      notes = []
      status = "matched"

      price_diff = po_line.unit_price.zero? ? line.unit_price : (line.unit_price - po_line.unit_price) / po_line.unit_price
      if price_diff.abs > price_tolerance
        status = "price_variance"
        notes << "Unit price #{money(line.unit_price)} vs PO #{money(po_line.unit_price)} (#{pct(price_diff)})"
      end

      billable = [po_line.received_quantity - po_line.invoiced_quantity, 0].max
      allowed = billable * (1 + quantity_tolerance)
      if line.quantity > allowed
        status = "quantity_variance" if status == "matched"
        notes << "Billed #{fmt(line.quantity)} but only #{fmt(billable)} received and not yet invoiced"
      end

      expected_qty = [line.quantity, billable].min
      base.merge(status: status, purchase_order_line_id: po_line.id, po_line_no: po_line.line_no,
                 po_unit_price: fmt(po_line.unit_price), received_quantity: fmt(po_line.received_quantity),
                 previously_invoiced: fmt(po_line.invoiced_quantity),
                 expected_amount: fmt((expected_qty * po_line.unit_price).round(2)), notes: notes)
    end

    def check(name, passed, failure_message)
      { name: name, passed: passed, message: passed ? nil : failure_message }
    end

    def price_tolerance = company.price_tolerance_pct.to_d / 100
    def quantity_tolerance = company.quantity_tolerance_pct.to_d / 100
    def fmt(d) = d.to_d.round(3).to_s("F")
    def money(d) = format("%.2f", d.to_d)
    def pct(d) = "#{d.positive? ? '+' : ''}#{(d * 100).round(1).to_s('F')}%"
  end
end
