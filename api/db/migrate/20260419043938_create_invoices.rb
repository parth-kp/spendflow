class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :company, null: false, foreign_key: true
      t.references :supplier, foreign_key: true
      t.references :purchase_order, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.string :invoice_number
      t.date :invoice_date
      t.date :due_date
      t.string :currency
      t.decimal :subtotal, precision: 14, scale: 2
      t.decimal :tax_amount, precision: 14, scale: 2, default: 0
      t.decimal :total_amount, precision: 14, scale: 2
      t.string :status, null: false, default: "uploaded"
      t.string :source, null: false, default: "upload"
      t.jsonb :extraction, null: false, default: {}
      t.string :extraction_error
      t.jsonb :match_result, null: false, default: {}
      t.decimal :match_confidence, precision: 5, scale: 4
      t.datetime :matched_at
      t.datetime :approved_at
      t.datetime :paid_at
      t.timestamps
    end

    create_table :invoice_lines do |t|
      t.references :invoice, null: false, foreign_key: { on_delete: :cascade }
      t.references :purchase_order_line, foreign_key: { on_delete: :nullify }
      t.integer :position, null: false, default: 0
      t.string :description, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 0
      t.decimal :unit_price, precision: 14, scale: 2, null: false, default: 0
      t.decimal :amount, precision: 14, scale: 2, null: false, default: 0
      t.string :match_status
      t.jsonb :match_notes, null: false, default: []
      t.timestamps
    end
  end
end
