class CreateApprovalRules < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_rules do |t|
      t.references :company, null: false, foreign_key: true
      t.references :department, foreign_key: true
      t.references :approver, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.integer :level, null: false
      t.decimal :min_amount, precision: 14, scale: 2, null: false, default: 0
      t.string :approver_role, null: false
      t.timestamps
    end
  end
end
