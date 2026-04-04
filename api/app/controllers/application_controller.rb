class ApplicationController < ActionController::API
  before_action :authenticate!

  attr_reader :current_user

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def authenticate!
    token = request.authorization.to_s.delete_prefix("Bearer ").presence
    return render_error(:unauthorized, "Missing token") unless token

    claims = AuthToken.decode(token)
    company = Company.find(claims["cid"])
    ActsAsTenant.current_tenant = company
    @current_user = company.users.active.find(claims["sub"])
  rescue AuthToken::Invalid, ActiveRecord::RecordNotFound
    render_error(:unauthorized, "Invalid or expired token")
  end

  def current_company
    ActsAsTenant.current_tenant
  end

  def render_error(status, message, details = nil)
    body = { error: message }
    body[:details] = details if details
    render json: body, status: status
  end

  def not_found
    render_error(:not_found, "Not found")
  end

  def unprocessable(exception)
    render_error(:unprocessable_content, "Validation failed", exception.record.errors.to_hash(true))
  end

  def bad_request(exception)
    render_error(:bad_request, exception.message)
  end
end
