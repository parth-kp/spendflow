class ApplicationRecord < ActiveRecord::Base
  include TenantGuard

  primary_abstract_class
end
