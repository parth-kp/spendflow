class CreateNumberSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :number_sequences do |t|
      t.references :company, null: false, foreign_key: true, index: false
      t.string :prefix, null: false
      t.bigint :value, null: false, default: 0
    end
    add_index :number_sequences, [:company_id, :prefix], unique: true
  end
end
