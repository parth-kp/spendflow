module Api
  module V1
    class RequisitionsController < ApplicationController
      before_action :load_requisition, except: %i[index create]

      def index
        scope = policy_scope(Requisition).includes(:requester, :department, :supplier)
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(requester_id: current_user.id) if params[:mine] == "true"
        scope = scope.where("requisitions.title ILIKE :q OR requisitions.number ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
        render json: RequisitionSerializer.collection(paginate(scope.order(created_at: :desc)))
      end

      def show
        authorize @requisition
        render_detail
      end

      def create
        @requisition = authorize Requisition.new(requisition_params.merge(requester: current_user))
        @requisition.department ||= current_user.department || current_company.departments.first
        @requisition.save!
        @requisition.audit!(:created)
        render_detail(:created)
      end

      def update
        authorize @requisition
        @requisition.update!(requisition_params)
        @requisition.audit!(:updated, changes: @requisition.saved_changes.except("updated_at").keys)
        render_detail
      end

      def destroy
        authorize @requisition
        @requisition.destroy!
        head :no_content
      end

      def submit
        authorize @requisition
        workflow.submit!
        render_detail
      end

      def approve
        authorize @requisition, :decide?
        workflow.decide!(:approve, comment: params[:comment])
        render_detail
      end

      def reject
        authorize @requisition, :decide?
        workflow.decide!(:reject, comment: params[:comment])
        render_detail
      end

      def cancel
        authorize @requisition
        @requisition.cancel!
        @requisition.audit!(:cancelled)
        render_detail
      end

      def revise
        authorize @requisition
        @requisition.revise!
        @requisition.audit!(:revised)
        render_detail
      end

      private

      def load_requisition
        @requisition = Requisition.includes(:lines, approval_steps: %i[approver decided_by]).find(params[:id])
      end

      def workflow
        Approvals::Workflow.new(@requisition, actor: current_user)
      end

      def requisition_params
        permitted = [:title, :justification, :needed_by, :supplier_id,
                     { lines_attributes: %i[id description quantity unit unit_price _destroy] }]
        permitted << :department_id if current_user.admin? || current_user.department.nil?
        params.require(:requisition).permit(*permitted)
      end

      def render_detail(status = :ok)
        policy = RequisitionPolicy.new(current_user, @requisition)
        permissions = %i[update submit cancel revise decide convert].index_with { |p| policy.public_send(:"#{p}?") }
        po = @requisition.purchase_order&.slice(:id, :number, :status)
        render json: RequisitionSerializer.new(@requisition, detail: true, permissions: permissions, purchase_order: po).as_json,
               status: status
      end
    end
  end
end
