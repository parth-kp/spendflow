module Matching
  # Optional second opinion from TypeSafe's Jev model: a calibrated probability
  # that the invoice really is a bill for this purchase order. Rule-based
  # checks still decide the match status; this is surfaced to the reviewer.
  class JevAdvisor
    ENDPOINT = "https://api.typesafe.ai/v1/systemone".freeze
    MODEL = "jev-1.14.0".freeze

    def self.available?
      ENV["TYPESAFE_API_KEY"].present?
    end

    def initialize(api_key: ENV.fetch("TYPESAFE_API_KEY", nil))
      @api_key = api_key
    end

    def probability(invoice, purchase_order)
      return unless api_key && purchase_order

      response = connection.post(ENDPOINT, {
        model: MODEL,
        state: state(invoice, purchase_order),
        questions: {
          same_purchase: {
            type: "noul",
            instructions: "Is `invoice` a bill for the goods or services ordered on `purchase_order`, " \
                          "from the same supplier, such that accounts payable should pay it against that order?",
            criteria: {
              true: "Supplier, items and amounts on the invoice correspond to the purchase order, allowing for " \
                    "different wording of item descriptions and small rounding differences.",
              false: "The invoice is for a different supplier, different items, or clearly different amounts."
            }
          }
        }
      })
      return unless response.success?

      response.body.dig("answers", "same_purchase", "noul")&.to_d&.round(4)
    rescue Faraday::Error => e
      Rails.logger.warn("[JevAdvisor] #{e.class}: #{e.message}")
      nil
    end

    private

    attr_reader :api_key

    def state(invoice, po)
      {
        invoice: {
          supplier: invoice.extraction["supplier_name"] || invoice.supplier&.name,
          number: invoice.invoice_number,
          quoted_po: invoice.extraction["po_number"],
          total: invoice.total_amount.to_s,
          lines: invoice.lines.map { |l| { description: l.description, quantity: l.quantity.to_s, unit_price: l.unit_price.to_s } }
        },
        purchase_order: {
          number: po.number,
          supplier: po.supplier.name,
          total: po.total_amount.to_s,
          lines: po.lines.map { |l| { description: l.description, quantity: l.quantity.to_s, unit_price: l.unit_price.to_s,
                                      received: l.received_quantity.to_s } }
        }
      }
    end

    def connection
      Faraday.new do |f|
        f.request :json
        f.response :json
        f.options.timeout = 10
        f.headers["Authorization"] = "Bearer #{api_key}"
      end
    end
  end
end
