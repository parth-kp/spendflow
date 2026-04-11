module Api
  module V1
    class SuppliersController < ApplicationController
      before_action :load_supplier, only: %i[show update destroy]

      def index
        suppliers = policy_scope(Supplier).search(params[:q]).order(:name)
        suppliers = suppliers.active if params[:active] == "true"
        render json: SupplierSerializer.collection(paginate(suppliers))
      end

      def show
        render json: SupplierSerializer.new(@supplier).as_json
      end

      def create
        supplier = authorize Supplier.new(supplier_params)
        supplier.save!
        render json: SupplierSerializer.new(supplier).as_json, status: :created
      end

      def update
        @supplier.update!(supplier_params)
        render json: SupplierSerializer.new(@supplier).as_json
      end

      def destroy
        @supplier.update!(active: false)
        head :no_content
      end

      private

      def load_supplier
        @supplier = authorize policy_scope(Supplier).find(params[:id])
      end

      def supplier_params
        params.require(:supplier).permit(:name, :email, :tax_id, :address, :payment_terms_days, :active)
      end
    end
  end
end
