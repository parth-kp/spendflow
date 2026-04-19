module Extraction
  # Normalizes and validates raw model output before anything touches the
  # database. Unknown or malformed values become nil rather than guesses.
  class Result
    class Invalid < StandardError; end

    attr_reader :data, :source, :warnings

    def self.from_raw(raw, source:)
      new(raw, source: source).tap(&:validate!)
    end

    def initialize(raw, source:)
      @source = source
      @warnings = []
      @data = normalize(raw.is_a?(Hash) ? raw.deep_stringify_keys : {})
    end

    def validate!
      raise Invalid, "No line items or total found" if data["line_items"].empty? && data["total_amount"].nil?

      lines_total = data["line_items"].sum { |l| l["amount"] || 0 }
      if data["subtotal"] && data["line_items"].any? && (lines_total - data["subtotal"]).abs > 0.05
        warnings << "Line items add up to #{lines_total.to_s('F')} but subtotal says #{data['subtotal'].to_s('F')}"
      end
      if data["subtotal"] && data["total_amount"] && (data["subtotal"] + (data["tax_amount"] || 0) - data["total_amount"]).abs > 0.05
        warnings << "Subtotal plus tax does not equal total"
      end
      self
    end

    def [](key) = data[key.to_s]

    def to_h
      data.merge("source" => source, "warnings" => warnings).transform_values { |v| serialize(v) }
    end

    private

    def normalize(raw)
      {
        "supplier_name" => str(raw["supplier_name"]),
        "invoice_number" => str(raw["invoice_number"]),
        "invoice_date" => date(raw["invoice_date"]),
        "due_date" => date(raw["due_date"]),
        "currency" => currency(raw["currency"]),
        "po_number" => str(raw["po_number"])&.upcase,
        "subtotal" => money(raw["subtotal"]),
        "tax_amount" => money(raw["tax_amount"]),
        "total_amount" => money(raw["total_amount"]),
        "confidence" => raw["confidence"].to_f.clamp(0.0, 1.0),
        "line_items" => Array(raw["line_items"]).filter_map { |l| line(l) }.first(200)
      }
    end

    def line(raw)
      return unless raw.is_a?(Hash)

      desc = str(raw["description"])
      return unless desc

      qty = number(raw["quantity"]) || BigDecimal("1")
      price = money(raw["unit_price"])
      amount = money(raw["amount"])
      price ||= (amount / qty).round(2) if amount && qty.positive?
      amount ||= (qty * price).round(2) if price
      { "description" => desc[0, 500], "quantity" => qty, "unit_price" => price || BigDecimal("0"),
        "amount" => amount || BigDecimal("0") }
    end

    def str(v) = v.is_a?(String) || v.is_a?(Numeric) ? v.to_s.strip.presence : nil

    def number(v)
      return if v.nil?

      cleaned = v.is_a?(String) ? v.gsub(/[^\d.\-]/, "") : v
      BigDecimal(cleaned.to_s)
    rescue ArgumentError
      nil
    end

    def money(v) = number(v)&.round(2)

    def date(v)
      Date.iso8601(v.to_s)
    rescue Date::Error
      begin
        Date.parse(v.to_s) if v.present?
      rescue Date::Error
        nil
      end
    end

    def currency(v)
      code = v.to_s.strip.upcase
      { "$" => "USD", "€" => "EUR", "£" => "GBP", "₹" => "INR" }.fetch(code, code[/\A[A-Z]{3}\z/])
    end

    def serialize(v)
      case v
      when BigDecimal then v.to_s("F")
      when Date then v.iso8601
      when Array then v.map { |x| x.is_a?(Hash) ? x.transform_values { |y| serialize(y) } : serialize(x) }
      else v
      end
    end
  end
end
