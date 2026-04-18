module Procurement
  class ReceiveGoods
    class Error < StandardError; end

    # quantities: { purchase_order_line_id => quantity }
    def initialize(purchase_order, actor:, quantities:, received_on: Date.current, notes: nil, allow_over_receipt: false)
      @po = purchase_order
      @actor = actor
      @quantities = quantities.to_h.transform_keys(&:to_i).transform_values(&:to_d).select { |_, q| q.positive? }
      @received_on = received_on
      @notes = notes
      @allow_over_receipt = allow_over_receipt
    end

    def call
      raise Error, "Nothing to receive" if quantities.empty?

      receipt = nil
      po.with_lock do
        raise Error, "#{po.number} is #{po.status.humanize.downcase}" unless po.issued? || po.partially_received?

        lines = po.lines.index_by(&:id)
        unknown = quantities.keys - lines.keys
        raise Error, "Lines #{unknown.join(', ')} are not on #{po.number}" if unknown.any?

        receipt = po.goods_receipts.build(company: po.company, received_by: actor, received_on: received_on, notes: notes)
        quantities.each do |line_id, qty|
          line = lines[line_id]
          if !allow_over_receipt && qty > line.open_quantity
            raise Error, "Line #{line.line_no}: receiving #{qty.to_s('F')} but only #{line.open_quantity.to_s('F')} open"
          end

          receipt.lines.build(purchase_order_line: line, quantity: qty)
          line.update!(received_quantity: line.received_quantity + qty)
        end
        receipt.save!
        po.register_receipt!

        po.audit!(:goods_received, actor: actor, receipt: receipt.number,
                                   lines: quantities.transform_keys { |id| lines[id].line_no }.transform_values { |q| q.to_s("F") })
      end
      receipt
    end

    private

    attr_reader :po, :actor, :quantities, :received_on, :notes, :allow_over_receipt
  end
end
