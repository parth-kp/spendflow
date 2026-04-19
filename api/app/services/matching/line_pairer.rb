module Matching
  # Greedy one-to-one pairing of invoice lines to PO lines, scored on
  # description token overlap and unit price closeness. Explicit links
  # (purchase_order_line_id already set) always win.
  class LinePairer
    MIN_SCORE = 0.35

    def initialize(invoice_lines, po_lines)
      @invoice_lines = invoice_lines
      @po_lines = po_lines
    end

    def call
      pairs = {}
      taken = Set.new

      invoice_lines.each do |line|
        explicit = po_lines.find { |pl| pl.id == line.purchase_order_line_id }
        next unless explicit

        pairs[line] = explicit
        taken << explicit.id
      end

      candidates = invoice_lines.reject { |l| pairs.key?(l) }.flat_map do |line|
        po_lines.reject { |pl| taken.include?(pl.id) }.map { |pl| [score(line, pl), line, pl] }
      end

      candidates.sort_by { |s, _, _| -s }.each do |s, line, pl|
        next if s < MIN_SCORE || pairs.key?(line) || taken.include?(pl.id)

        pairs[line] = pl
        taken << pl.id
      end

      pairs
    end

    private

    attr_reader :invoice_lines, :po_lines

    def score(line, po_line)
      a = tokens(line.description)
      b = tokens(po_line.description)
      text = a.empty? || b.empty? ? 0.0 : (a & b).size.to_f / (a | b).size
      price = if po_line.unit_price.zero? then 0.0
              else [1 - ((line.unit_price - po_line.unit_price).abs / po_line.unit_price).to_f, 0].max
              end
      (0.7 * text) + (0.3 * price)
    end

    def tokens(str)
      str.to_s.downcase.scan(/[a-z0-9]+/).reject { |t| t.size < 2 }.to_set
    end
  end
end
