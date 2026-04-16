class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Paginatable

  before_action :authenticate!
  after_action :verify_authorized, unless: -> { action_name == "index" }
  after_action :verify_policy_scoped, if: -> { action_name == "index" }

  attr_reader :current_user

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from AASM::InvalidTransition, with: :conflict
  rescue_from Approvals::Workflow::Error, with: :conflict

  private

  def authenticate!
    token = request.authorization.to_s.delete_prefix("Bearer ").presence
    return render_error(:unauthorized, "Missing token") unless token

    claims = AuthToken.decode(token)
    company = Company.find(claims["cid"])
    ActsAsTenant.current_tenant = company
    @current_user = company.users.active.find(claims["sub"])
    Current.user = @current_user
    Current.request_id = request.request_id
    Current.ip_address = request.remote_ip
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

  def conflict(exception)
    render_error(:conflict, exception.message)
  end

  def forbidden
    render_error(:forbidden, "You are not allowed to do that")
  end

  def bad_request(exception)
    render_error(:bad_request, exception.message)
  end
end
