module Api
  module V1
    class InvoicesController < ApplicationController
      before_action :load_invoice, except: %i[index create]

      rescue_from Invoices::Approve::Error, with: :conflict

      def index
        scope = policy_scope(Invoice).includes(:supplier, :purchase_order)
        scope = scope.where(status: params[:status].to_s.split(",")) if params[:status].present?
        scope = scope.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
        render json: InvoiceSerializer.collection(paginate(scope.order(created_at: :desc)))
      end

      def show
        authorize @invoice
        render_detail
      end

      def create
        @invoice = authorize Invoice.new(uploaded_by: current_user)
        if params[:document].present?
          @invoice.assign_attributes(source: "upload", document: params[:document],
                                     supplier_id: params[:supplier_id].presence,
                                     purchase_order_id: params[:purchase_order_id].presence)
          @invoice.save!
          @invoice.audit!(:uploaded, filename: @invoice.document.filename.to_s)
          ProcessInvoiceJob.perform_later(company_id: current_company.id, invoice_id: @invoice.id)
        else
          @invoice.assign_attributes(manual_params.merge(source: "manual"))
          @invoice.recalculate_totals
          @invoice.save!
          @invoice.finish_extraction!
          @invoice.audit!(:created_manually)
          Invoices::RunMatch.new(@invoice, actor: current_user).call
        end
        render_detail(:created)
      end

      def update
        authorize @invoice
        @invoice.assign_attributes(manual_params)
        @invoice.recalculate_totals
        @invoice.save!
        @invoice.audit!(:edited, fields: @invoice.saved_changes.except("updated_at").keys)
        Invoices::RunMatch.new(@invoice.reload, actor: current_user).call if @invoice.matchable?
        render_detail
      end

      def document
        authorize @invoice
        return head :not_found unless @invoice.document.attached?

        send_data @invoice.document.download, filename: @invoice.document.filename.to_s,
                                              type: @invoice.document.content_type, disposition: "inline"
      end

      def rematch
        authorize @invoice
        Invoices::RunMatch.new(@invoice, actor: current_user).call
        render_detail
      end

      def reprocess
        authorize @invoice
        @invoice.audit!(:reprocess_requested)
        ProcessInvoiceJob.perform_later(company_id: current_company.id, invoice_id: @invoice.id)
        render_detail(:accepted)
      end

      def approve
        authorize @invoice
        Invoices::Approve.new(@invoice, actor: current_user, comment: params[:comment]).call
        render_detail
      end

      def reject
        authorize @invoice
        return render_error(:unprocessable_content, "A reason is required") if params[:comment].blank?

        @invoice.reject!
        @invoice.audit!(:rejected, comment: params[:comment])
        render_detail
      end

      def pay
        authorize @invoice
        @invoice.mark_paid!
        @invoice.audit!(:paid, reference: params[:reference])
        render_detail
      end

      private

      def load_invoice
        @invoice = Invoice.includes(:lines, :supplier, :purchase_order, :uploaded_by, :approved_by).find(params[:id])
      end

      def manual_params
        params.require(:invoice).permit(
          :supplier_id, :purchase_order_id, :invoice_number, :invoice_date, :due_date, :currency, :tax_amount,
          lines_attributes: %i[id description quantity unit_price amount purchase_order_line_id _destroy]
        )
      end

      def render_detail(status = :ok)
        policy = InvoicePolicy.new(current_user, @invoice)
        permissions = %i[update rematch reprocess approve reject pay].index_with { |p| policy.public_send(:"#{p}?") }
        render json: InvoiceSerializer.new(@invoice, detail: true, permissions: permissions).as_json, status: status
      end
    end
  end
end
