ActsAsTenant.configure do |config|
  config.require_tenant = lambda do
    !Rails.env.test? && !defined?(Rails::Console)
  end
end
