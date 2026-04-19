module Extraction
  module Schema
    FIELDS = {
      type: "object",
      additionalProperties: false,
      required: %w[supplier_name invoice_number invoice_date due_date currency po_number subtotal tax_amount
                   total_amount line_items confidence],
      properties: {
        supplier_name: { type: %w[string null] },
        invoice_number: { type: %w[string null] },
        invoice_date: { type: %w[string null], description: "ISO 8601 date (YYYY-MM-DD)" },
        due_date: { type: %w[string null], description: "ISO 8601 date (YYYY-MM-DD)" },
        currency: { type: %w[string null], description: "ISO 4217 code, e.g. USD" },
        po_number: { type: %w[string null], description: "Buyer purchase order reference, e.g. PO-00012" },
        subtotal: { type: %w[number null] },
        tax_amount: { type: %w[number null] },
        total_amount: { type: %w[number null] },
        line_items: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[description quantity unit_price amount],
            properties: {
              description: { type: "string" },
              quantity: { type: %w[number null] },
              unit_price: { type: %w[number null] },
              amount: { type: %w[number null] }
            }
          }
        },
        confidence: { type: "number", description: "0..1, how sure you are the fields are correct" }
      }
    }.freeze
  end
end
