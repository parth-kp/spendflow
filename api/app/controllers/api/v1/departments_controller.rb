module Api
  module V1
    class DepartmentsController < ApplicationController
      def index
        departments = policy_scope(Department).order(:name)
        counts = User.where(department_id: departments.select(:id)).group(:department_id).count
        render json: departments.map { |d| serialize(d, counts[d.id] || 0) }
      end

      def create
        department = authorize Department.new(department_params)
        department.save!
        render json: serialize(department, 0), status: :created
      end

      def update
        department = authorize Department.find(params[:id])
        department.update!(department_params)
        render json: serialize(department, department.users.count)
      end

      def destroy
        authorize(Department.find(params[:id])).destroy!
        head :no_content
      end

      private

      def department_params = params.require(:department).permit(:name, :code)

      def serialize(d, user_count)
        { id: d.id, name: d.name, code: d.code, user_count: user_count }
      end
    end
  end
end
