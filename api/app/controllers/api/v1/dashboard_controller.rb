module Api
  module V1
    class DashboardController < ApplicationController
      def show
        skip_authorization
        render json: DashboardQuery.new(current_user).call
      end
    end
  end
end
