class CreateApprovalSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_steps do |t|
      t.references :company, null: false, foreign_key: true
      t.references :requisition, null: false, foreign_key: true
      t.references :approval_rule, foreign_key: { on_delete: :nullify }
      t.references :approver, foreign_key: { to_table: :users }
      t.references :decided_by, foreign_key: { to_table: :users }
      t.integer :level, null: false
      t.string :approver_role, null: false
      t.string :status, null: false, default: "pending"
      t.text :comment
      t.datetime :decided_at
      t.timestamps
    end
    add_index :approval_steps, [:requisition_id, :level], unique: true
  end
end
