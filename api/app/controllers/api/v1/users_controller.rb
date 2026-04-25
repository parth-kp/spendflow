module Api
  module V1
    class UsersController < ApplicationController
      def index
        users = policy_scope(User).includes(:department, :company).order(:name)
        users = users.where(role: params[:role]) if params[:role].present?
        users = users.active unless params[:include_inactive] == "true"
        render json: UserSerializer.collection(users)
      end

      def show
        render json: UserSerializer.new(authorize(User.find(params[:id]))).as_json
      end

      def create
        user = authorize User.new
        user.assign_attributes(permitted_attributes(user))
        user.save!
        render json: UserSerializer.new(user).as_json, status: :created
      end

      def update
        user = authorize User.find(params[:id])
        attrs = permitted_attributes(user)
        attrs = attrs.except(:password) if attrs[:password].blank?
        user.update!(attrs)
        render json: UserSerializer.new(user).as_json
      end
    end
  end
end
