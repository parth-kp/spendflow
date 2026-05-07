export type Role = 'employee' | 'manager' | 'finance' | 'admin'

export interface Ref {
  id: number
  name: string
}

export interface User {
  id: number
  name: string
  email: string
  role: Role
  department: Ref | null
  company: { id: number; name: string; currency: string }
}

export type RequisitionStatus = 'draft' | 'pending_approval' | 'approved' | 'rejected' | 'cancelled' | 'ordered'

export interface RequisitionLine {
  id?: number
  description: string
  quantity: string
  unit: string
  unit_price: string
  line_total?: string
  _destroy?: boolean
}

export interface ApprovalStep {
  id: number
  level: number
  approver_role: Role
  status: 'pending' | 'approved' | 'rejected' | 'skipped'
  approver: Ref | null
  decided_by: Ref | null
  decided_at: string | null
  comment: string | null
}

export interface Requisition {
  id: number
  number: string
  title: string
  status: RequisitionStatus
  total_amount: string
  currency: string
  needed_by: string | null
  submitted_at: string | null
  approved_at: string | null
  created_at: string
  requester: Ref
  department: Ref
  supplier: Ref | null
}

export interface RequisitionDetail extends Requisition {
  justification: string | null
  supplier_id: number | null
  lines: RequisitionLine[]
  approval_steps: ApprovalStep[]
  purchase_order: { id: number; number: string; status: string } | null
  permissions: Record<'update' | 'submit' | 'cancel' | 'revise' | 'decide' | 'convert', boolean>
}

export type PoStatus = 'issued' | 'partially_received' | 'received' | 'closed' | 'cancelled'

export interface PurchaseOrder {
  id: number
  number: string
  status: PoStatus
  total_amount: string
  currency: string
  expected_on: string | null
  issued_at: string | null
  supplier: Ref
  requisition: { id: number; number: string; title: string } | null
}

export interface PoLine {
  id: number
  line_no: number
  description: string
  unit: string
  quantity: string
  unit_price: string
  amount: string
  received_quantity: string
  invoiced_quantity: string
}

export interface PurchaseOrderDetail extends PurchaseOrder {
  lines: PoLine[]
  receipts: {
    id: number
    number: string
    received_on: string
    notes: string | null
    received_by: Ref
    lines: { purchase_order_line_id: number; quantity: string }[]
  }[]
  permissions: Record<'receive' | 'close' | 'cancel', boolean>
}

export type InvoiceStatus =
  | 'uploaded'
  | 'processing'
  | 'extraction_failed'
  | 'extracted'
  | 'matched'
  | 'exception'
  | 'approved'
  | 'rejected'
  | 'paid'

export interface Invoice {
  id: number
  invoice_number: string | null
  status: InvoiceStatus
  source: 'upload' | 'manual'
  invoice_date: string | null
  due_date: string | null
  currency: string | null
  subtotal: string | null
  tax_amount: string | null
  total_amount: string | null
  match_confidence: number | null
  supplier: Ref | null
  purchase_order: { id: number; number: string } | null
  created_at: string
}

export type LineMatchStatus = 'matched' | 'price_variance' | 'quantity_variance' | 'unmatched'

export interface MatchLine {
  invoice_line_id: number
  description: string
  quantity: string
  unit_price: string
  status: LineMatchStatus
  purchase_order_line_id: number | null
  po_line_no?: number
  po_unit_price?: string
  received_quantity?: string
  previously_invoiced?: string
  expected_amount: string
  notes: string[]
}

export interface InvoiceDetail extends Invoice {
  extraction: Record<string, unknown> & { source?: string; confidence?: number; warnings?: string[] }
  extraction_error: string | null
  match_result: {
    status?: 'matched' | 'exception'
    checks?: { name: string; passed: boolean; message: string | null }[]
    lines?: MatchLine[]
  }
  document: false | { filename: string; content_type: string; byte_size: number }
  uploaded_by: Ref
  approved_by: Ref | null
  approved_at: string | null
  paid_at: string | null
  lines: {
    id: number
    position: number
    description: string
    quantity: string
    unit_price: string
    amount: string
    purchase_order_line_id: number | null
    match_status: LineMatchStatus | null
    match_notes: string[]
  }[]
  permissions: Record<'update' | 'rematch' | 'reprocess' | 'approve' | 'reject' | 'pay', boolean>
}

export interface Supplier {
  id: number
  name: string
  email: string | null
  tax_id: string | null
  address: string | null
  payment_terms_days: number
  active: boolean
}

export interface Department {
  id: number
  name: string
  code: string
  user_count: number
}

export interface ApprovalRule {
  id: number
  name: string
  level: number
  min_amount: string
  approver_role: Role
  department: Ref | null
  approver: Ref | null
}

export interface AuditEvent {
  id: number
  action: string
  metadata: Record<string, unknown>
  created_at: string
  ip_address: string | null
  actor: (Ref & { role: Role }) | null
  auditable: { type: string; id: number; label: string | null }
}

export interface Notification {
  id: number
  kind: string
  title: string
  body: string | null
  read_at: string | null
  created_at: string
  subject: { type: string; id: number } | null
}

export interface Dashboard {
  my_requisitions: Partial<Record<RequisitionStatus, number>>
  awaiting_my_approval: number
  invoices_by_status?: Partial<Record<InvoiceStatus, number>>
  open_po_value?: string
  payables_due_7d?: string
  spend_by_department?: Record<string, string>
  top_suppliers?: { name: string; total: string }[]
  avg_approval_hours?: number | null
}
