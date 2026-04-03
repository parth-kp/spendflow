class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :currency, null: false, default: "USD"
      t.decimal :price_tolerance_pct, precision: 5, scale: 2, null: false, default: 2.0
      t.decimal :quantity_tolerance_pct, precision: 5, scale: 2, null: false, default: 0.0
      t.timestamps
    end
    add_index :companies, :slug, unique: true
  end
end
