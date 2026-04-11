class NumberSequence < ApplicationRecord
  belongs_to :company

  def self.next_for(company, prefix)
    sql = <<~SQL
      INSERT INTO number_sequences (company_id, prefix, value)
      VALUES ($1, $2, 1)
      ON CONFLICT (company_id, prefix)
      DO UPDATE SET value = number_sequences.value + 1
      RETURNING value
    SQL
    value = connection.exec_query(sql, "NumberSequence", [company.id, prefix]).rows.first.first
    format("%s-%05d", prefix, value)
  end
end
