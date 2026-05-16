# In development and production every query against a tenant-scoped model must
# run with a tenant set. In tests that would break factories, so it is enforced
# only while a request is being processed (see TenantEnforcement::Middleware).
module TenantEnforcement
  def self.active?
    Thread.current[:spendflow_enforce_tenant] == true
  end

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Thread.current[:spendflow_enforce_tenant] = true
      @app.call(env)
    ensure
      Thread.current[:spendflow_enforce_tenant] = nil
    end
  end
end

ActsAsTenant.configure do |config|
  config.require_tenant = lambda do
    if Rails.env.test?
      TenantEnforcement.active?
    else
      !defined?(Rails::Console)
    end
  end
end

Rails.application.config.middleware.use TenantEnforcement::Middleware if Rails.env.test?
