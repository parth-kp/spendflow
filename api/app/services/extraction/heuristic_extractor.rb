module Extraction
  # Offline fallback used when no LLM key is configured (tests, CI, local demo
  # without credentials). Handles simple text invoices with labelled fields and
  # "description  qty  x  price" style lines.
  class HeuristicExtractor
    LINE_PATTERN = /^\s*(?<desc>[A-Za-z][^\n]*?)\s+(?<qty>\d+(?:\.\d+)?)\s*(?:x|@|×)\s*\$?(?<price>[\d,]+(?:\.\d+)?)/i

    def self.available? = true

    def call(payload)
      text = payload.text.to_s
      raise Error, "No text layer to read without an LLM" if text.blank?

      Result.from_raw({
        "supplier_name" => field(text, /(?:from|supplier|vendor)\s*:\s*(.+)/i),
        "invoice_number" => field(text, /invoice\s*(?:no\.?|number|#)\s*:?\s*([A-Z0-9\-\/]+)/i),
        "invoice_date" => field(text, /(?:invoice\s+)?date\s*:\s*([^\n]+)/i),
        "due_date" => field(text, /due(?:\s+date)?\s*:\s*([^\n]+)/i),
        "currency" => field(text, /currency\s*:\s*([A-Z]{3})/i) || (text.include?("$") ? "USD" : nil),
        "po_number" => field(text, /\b(PO-\d+)\b/i),
        "subtotal" => field(text, /subtotal\s*:?\s*\$?([\d,]+\.?\d*)/i),
        "tax_amount" => field(text, /tax[^:\n]*:\s*\$?([\d,]+\.?\d*)/i),
        "total_amount" => field(text, /(?:^|\n)\s*total\s*(?:due)?\s*:?\s*\$?([\d,]+\.?\d*)/i),
        "line_items" => text.scan(LINE_PATTERN).map do |desc, qty, price|
          { "description" => desc.strip, "quantity" => qty, "unit_price" => price.delete(","), "amount" => nil }
        end,
        "confidence" => 0.5
      }, source: "heuristic")
    end

    class Error < StandardError; end

    private

    def field(text, pattern)
      text[pattern, 1]&.strip
    end
  end
end
