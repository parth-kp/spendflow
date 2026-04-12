class CreateRequisitions < ActiveRecord::Migration[8.1]
  def change
    create_table :requisitions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :department, null: false, foreign_key: true
      t.references :supplier, foreign_key: true
      t.string :number, null: false
      t.string :title, null: false
      t.text :justification
      t.string :status, null: false, default: "draft"
      t.decimal :total_amount, precision: 14, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: "USD"
      t.date :needed_by
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :rejected_at
      t.timestamps
    end
    add_index :requisitions, [:company_id, :number], unique: true

    create_table :requisition_lines do |t|
      t.references :requisition, null: false, foreign_key: { on_delete: :cascade }
      t.string :description, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.string :unit, null: false, default: "ea"
      t.decimal :unit_price, precision: 14, scale: 2, null: false
      t.decimal :line_total, precision: 14, scale: 2, null: false, default: 0
      t.timestamps
    end
  end
end
