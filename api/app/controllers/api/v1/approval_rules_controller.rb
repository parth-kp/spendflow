module Api
  module V1
    class ApprovalRulesController < ApplicationController
      def index
        rules = policy_scope(ApprovalRule).includes(:department, :approver).order(:level, :min_amount)
        render json: rules.map { |r| serialize(r) }
      end

      def create
        rule = authorize ApprovalRule.new(rule_params)
        rule.save!
        render json: serialize(rule), status: :created
      end

      def update
        rule = authorize ApprovalRule.find(params[:id])
        rule.update!(rule_params)
        render json: serialize(rule)
      end

      def destroy
        authorize(ApprovalRule.find(params[:id])).destroy!
        head :no_content
      end

      def preview
        authorize ApprovalRule, :index?
        department = params[:department_id].present? ? Department.find(params[:department_id]) : nil
        chain = ApprovalRule.chain_for(department: department, amount: params.require(:amount).to_d)
        render json: chain.map { |r| serialize(r) }
      end

      private

      def rule_params
        params.require(:approval_rule).permit(:name, :level, :min_amount, :approver_role, :department_id, :approver_id)
      end

      def serialize(r)
        { id: r.id, name: r.name, level: r.level, min_amount: r.min_amount.to_s("F"), approver_role: r.approver_role,
          department: r.department&.slice(:id, :name), approver: r.approver&.slice(:id, :name) }
      end
    end
  end
end
