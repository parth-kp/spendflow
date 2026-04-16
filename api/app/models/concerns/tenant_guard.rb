module TenantGuard
  extend ActiveSupport::Concern

  class_methods do
    # With a tenant set, acts_as_tenant scopes the association lookup, so a
    # foreign id resolves to nil instead of failing. Check the raw key too.
    def validates_same_tenant(*associations)
      validate do
        associations.each do |name|
          reflection = self.class.reflect_on_association(name)
          id = public_send(reflection.foreign_key)
          next if id.nil?

          other = reflection.klass.unscoped.find_by(id: id)
          next if other && other.company_id == company_id

          errors.add(name, "must belong to the same company")
        end
      end
    end
  end
end
