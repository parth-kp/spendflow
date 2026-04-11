class SupplierSerializer < BaseSerializer
  def as_json(*)
    object.slice(:id, :name, :email, :tax_id, :address, :payment_terms_days, :active).symbolize_keys
  end
end
