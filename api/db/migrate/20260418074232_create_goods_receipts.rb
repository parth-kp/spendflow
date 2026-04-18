class CreateGoodsReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :goods_receipts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :purchase_order, null: false, foreign_key: true
      t.references :received_by, null: false, foreign_key: { to_table: :users }
      t.string :number, null: false
      t.date :received_on, null: false
      t.text :notes
      t.timestamps
    end
    add_index :goods_receipts, [:company_id, :number], unique: true

    create_table :goods_receipt_lines do |t|
      t.references :goods_receipt, null: false, foreign_key: { on_delete: :cascade }
      t.references :purchase_order_line, null: false, foreign_key: true
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.timestamps
    end
  end
end
