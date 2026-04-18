class CreatePurchaseOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_orders do |t|
      t.references :company, null: false, foreign_key: true
      t.references :requisition, foreign_key: true, index: { unique: true }
      t.references :supplier, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :number, null: false
      t.string :status, null: false, default: "issued"
      t.decimal :total_amount, precision: 14, scale: 2, null: false, default: 0
      t.string :currency, null: false
      t.date :expected_on
      t.datetime :issued_at
      t.datetime :closed_at
      t.timestamps
    end
    add_index :purchase_orders, [:company_id, :number], unique: true

    create_table :purchase_order_lines do |t|
      t.references :purchase_order, null: false, foreign_key: { on_delete: :cascade }
      t.references :requisition_line, foreign_key: { on_delete: :nullify }
      t.integer :line_no, null: false
      t.string :description, null: false
      t.string :unit, null: false, default: "ea"
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.decimal :unit_price, precision: 14, scale: 2, null: false
      t.decimal :received_quantity, precision: 12, scale: 3, null: false, default: 0
      t.decimal :invoiced_quantity, precision: 12, scale: 3, null: false, default: 0
      t.timestamps
    end
    add_index :purchase_order_lines, [:purchase_order_id, :line_no], unique: true
  end
end
