class AddCurrentApproverToRequisitions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :requisitions, :current_approver_role, :string
    add_reference :requisitions, :current_approver, foreign_key: { to_table: :users }, index: false

    execute <<~SQL
      UPDATE requisitions r
      SET current_approver_role = s.approver_role, current_approver_id = s.approver_id
      FROM (
        SELECT DISTINCT ON (requisition_id) requisition_id, approver_role, approver_id
        FROM approval_steps WHERE status = 'pending'
        ORDER BY requisition_id, level
      ) s
      WHERE s.requisition_id = r.id AND r.status = 'pending_approval'
    SQL

    add_index :requisitions, %i[company_id current_approver_role department_id submitted_at],
              where: "status = 'pending_approval'", algorithm: :concurrently, name: "idx_requisitions_inbox"
    add_index :requisitions, %i[current_approver_id submitted_at],
              where: "status = 'pending_approval' AND current_approver_id IS NOT NULL", algorithm: :concurrently,
              name: "idx_requisitions_inbox_named"
  end

  def down
    remove_index :requisitions, name: "idx_requisitions_inbox_named"
    remove_index :requisitions, name: "idx_requisitions_inbox"
    remove_reference :requisitions, :current_approver
    remove_column :requisitions, :current_approver_role
  end
end
