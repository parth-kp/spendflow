class UserSerializer < BaseSerializer
  def as_json(*)
    {
      id: object.id,
      name: object.name,
      email: object.email,
      role: object.role,
      department: object.department && { id: object.department.id, name: object.department.name },
      company: { id: object.company.id, name: object.company.name, currency: object.company.currency }
    }
  end
end
