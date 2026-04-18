module Api
  module V1
    class PurchaseOrdersController < ApplicationController
      before_action :load_po, except: %i[index create]

      rescue_from Procurement::IssuePurchaseOrder::Error, Procurement::ReceiveGoods::Error, with: :conflict

      def index
        scope = policy_scope(PurchaseOrder).includes(:supplier, :requisition)
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
        render json: PurchaseOrderSerializer.collection(paginate(scope.order(created_at: :desc)))
      end

      def show
        authorize @po
        render_detail
      end

      def create
        requisition = Requisition.find(params.require(:requisition_id))
        authorize requisition, :convert?
        supplier = params[:supplier_id].present? ? Supplier.find(params[:supplier_id]) : nil
        @po = Procurement::IssuePurchaseOrder.new(requisition, actor: current_user, supplier: supplier,
                                                                expected_on: params[:expected_on]).call
        render_detail(:created)
      end

      def receive
        authorize @po
        quantities = params.require(:lines).map { |l| [l[:purchase_order_line_id], l[:quantity]] }.to_h
        Procurement::ReceiveGoods.new(@po, actor: current_user, quantities: quantities, notes: params[:notes],
                                           received_on: params[:received_on].presence || Date.current).call
        @po.reload
        render_detail(:created)
      end

      def close
        authorize @po
        @po.close!
        @po.audit!(:closed)
        render_detail
      end

      def cancel
        authorize @po
        @po.cancel!
        @po.audit!(:cancelled)
        render_detail
      end

      private

      def load_po
        @po = PurchaseOrder.includes(:lines, :supplier, :requisition, goods_receipts: %i[lines received_by])
                           .find(params[:id])
      end

      def render_detail(status = :ok)
        policy = PurchaseOrderPolicy.new(current_user, @po)
        permissions = %i[receive close cancel].index_with { |p| policy.public_send(:"#{p}?") }
        render json: PurchaseOrderSerializer.new(@po, detail: true, permissions: permissions).as_json, status: status
      end
    end
  end
end
