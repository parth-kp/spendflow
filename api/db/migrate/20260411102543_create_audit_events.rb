class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :company, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :auditable, polymorphic: true, null: false
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :request_id
      t.string :ip_address
      t.datetime :created_at, null: false
    end
  end
end
