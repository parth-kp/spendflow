FactoryBot.define do
  factory :purchase_order do
    company
    supplier { association :supplier, company: company }
    created_by { association :user, :finance, company: company }
    currency { "USD" }
    issued_at { Time.current }

    transient do
      line_specs { [{ description: "Widget", quantity: 10, unit_price: 25 }] }
    end

    after(:build) do |po, ctx|
      if po.lines.empty?
        ctx.line_specs.each_with_index { |spec, i| po.lines.build(spec.merge(line_no: i + 1)) }
      end
      po.recalculate_total
    end
  end
end
