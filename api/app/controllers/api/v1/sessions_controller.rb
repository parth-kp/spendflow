module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :authenticate!, only: :create
      skip_after_action :verify_authorized

      def create
        user = User.unscoped.active.find_by("lower(email) = ?", params.require(:email).to_s.downcase)

        if user&.authenticate(params.require(:password))
          ActsAsTenant.current_tenant = user.company
          render json: { token: AuthToken.issue(user), user: UserSerializer.new(user).as_json }, status: :created
        else
          render_error(:unauthorized, "Invalid email or password")
        end
      end

      def show
        render json: { user: UserSerializer.new(current_user).as_json }
      end
    end
  end
end
