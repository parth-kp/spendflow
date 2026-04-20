module Matching
  # Picks the PO an extracted invoice most likely belongs to:
  # 1. an exact PO number quoted on the invoice,
  # 2. otherwise the supplier's open PO whose total is closest to the invoice total.
  class PurchaseOrderFinder
    OPEN_STATUSES = %w[issued partially_received received].freeze

    def initialize(po_number:, supplier:, total:)
      @po_number = po_number
      @supplier = supplier
      @total = total
    end

    def call
      by_number || by_supplier_and_amount
    end

    def candidates(limit: 5)
      return PurchaseOrder.none unless supplier

      PurchaseOrder.where(supplier: supplier, status: OPEN_STATUSES)
                   .order(Arel.sql(PurchaseOrder.sanitize_sql_array(["ABS(total_amount - ?)", total.to_d])))
                   .limit(limit)
    end

    private

    attr_reader :po_number, :supplier, :total

    def by_number
      return if po_number.blank?

      normalized = po_number.to_s.upcase[/PO-?\s*0*(\d+)/, 1]
      return unless normalized

      PurchaseOrder.find_by(number: format("PO-%05d", normalized.to_i))
    end

    def by_supplier_and_amount
      return unless supplier && total

      candidates(limit: 1).first
    end
  end
end
