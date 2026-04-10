class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :tax_id
      t.string :address
      t.integer :payment_terms_days, null: false, default: 30
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :suppliers, [:company_id, :name], unique: true
  end
end
