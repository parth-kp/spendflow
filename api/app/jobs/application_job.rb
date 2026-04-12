class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  private

  # acts_as_tenant state does not cross the process boundary into Sidekiq,
  # so every tenant-aware job receives the company explicitly.
  def with_company(company_id, &)
    ActsAsTenant.with_tenant(Company.find(company_id), &)
  end
end
