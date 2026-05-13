import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Dialog } from '../components/Dialog'
import { History } from '../components/History'
import { Stamp, Status } from '../components/Stamp'
import { ErrorNote, Field, Loading, PageHeader, Sheet, SheetTitle } from '../components/ui'
import { api } from '../lib/api'
import { date, dateTime, money, qty } from '../lib/format'
import type { PurchaseOrderDetail, RequisitionDetail as Req, Supplier } from '../lib/types'

const ROLE_LABEL = { manager: 'Department manager', finance: 'Finance', admin: 'Executive (admin)', employee: 'Employee' }

export function RequisitionDetail() {
  const { id } = useParams()
  const qc = useQueryClient()
  const navigate = useNavigate()
  const [decision, setDecision] = useState<'approve' | 'reject' | null>(null)
  const [converting, setConverting] = useState(false)

  const { data: r, error, isPending } = useQuery({
    queryKey: ['requisition', id],
    queryFn: () => api.get<Req>(`/requisitions/${id}`),
  })

  const act = useMutation({
    mutationFn: ({ action, comment }: { action: string; comment?: string }) =>
      api.post<Req>(`/requisitions/${id}/${action}`, comment ? { comment } : undefined),
    onSuccess: (data) => {
      qc.setQueryData(['requisition', id], data)
      qc.invalidateQueries({ queryKey: ['requisitions'] })
      qc.invalidateQueries({ queryKey: ['audit', 'Requisition'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      setDecision(null)
    },
  })

  if (isPending) return <Loading />
  if (error) return <ErrorNote error={error} />

  const p = r.permissions
  const stampNote =
    r.status === 'approved' ? date(r.approved_at) : r.status === 'pending_approval' ? `Level ${r.approval_steps.find((s) => s.status === 'pending')?.level ?? ''}` : undefined

  return (
    <>
      <PageHeader
        back={{ to: '/requisitions', label: 'Requisitions' }}
        title={r.title}
        subtitle={`${r.number}, requested by ${r.requester.name} for ${r.department.name}`}
        actions={
          <>
            {p.update && <Link to={`/requisitions/${r.id}/edit`} className="btn-quiet">Edit</Link>}
            {p.submit && <button className="btn-primary" disabled={act.isPending} onClick={() => act.mutate({ action: 'submit' })}>Submit for approval</button>}
            {p.revise && <button className="btn-quiet" onClick={() => act.mutate({ action: 'revise' })}>Reopen as draft</button>}
            {p.cancel && <button className="btn-reject" onClick={() => confirm('Cancel this requisition?') && act.mutate({ action: 'cancel' })}>Cancel</button>}
            {p.decide && (
              <>
                <button className="btn-reject" onClick={() => setDecision('reject')}>Reject</button>
                <button className="btn-approve" onClick={() => setDecision('approve')}>Approve</button>
              </>
            )}
            {p.convert && <button className="btn-primary" onClick={() => setConverting(true)}>Issue purchase order</button>}
          </>
        }
      />
      {act.error && <div className="mb-4"><ErrorNote error={act.error} /></div>}

      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <div className="space-y-6">
          <Sheet>
            <div className="flex flex-wrap items-start justify-between gap-4 p-4">
              <dl className="grid grid-cols-2 gap-x-8 gap-y-3 text-sm sm:grid-cols-3">
                <div><dt className="text-ink-soft">Total</dt><dd className="text-xl font-bold tabular-nums">{money(r.total_amount, r.currency)}</dd></div>
                <div><dt className="text-ink-soft">Preferred supplier</dt><dd>{r.supplier?.name ?? 'None'}</dd></div>
                <div><dt className="text-ink-soft">Needed by</dt><dd>{date(r.needed_by)}</dd></div>
                <div><dt className="text-ink-soft">Submitted</dt><dd>{dateTime(r.submitted_at)}</dd></div>
                {r.purchase_order && (
                  <div><dt className="text-ink-soft">Purchase order</dt>
                    <dd><Link className="text-carbon hover:underline" to={`/purchase-orders/${r.purchase_order.id}`}>{r.purchase_order.number}</Link></dd></div>
                )}
              </dl>
              <Stamp value={r.status} note={stampNote} />
            </div>
            {r.justification && <p className="border-t border-rule px-4 py-3 text-sm text-ink-soft">{r.justification}</p>}
          </Sheet>

          <Sheet>
            <SheetTitle>Items</SheetTitle>
            <div className="overflow-x-auto">
              <table className="table">
                <thead><tr><th>Description</th><th className="num">Qty</th><th className="num">Unit price</th><th className="num">Amount</th></tr></thead>
                <tbody>
                  {r.lines.map((l) => (
                    <tr key={l.id}>
                      <td>{l.description}</td>
                      <td className="num">{qty(l.quantity)} {l.unit}</td>
                      <td className="num">{money(l.unit_price, r.currency)}</td>
                      <td className="num font-medium">{money(l.line_total, r.currency)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Sheet>
        </div>

        <div className="space-y-6">
          <Sheet>
            <SheetTitle>Approval chain</SheetTitle>
            {r.approval_steps.length === 0 ? (
              <p className="px-4 py-4 text-sm text-ink-soft">
                {r.status === 'draft' ? 'Approvers are chosen when you submit, based on amount and department.' : 'No approval was required.'}
              </p>
            ) : (
              <ol className="divide-y divide-rule/70">
                {r.approval_steps.map((s) => (
                  <li key={s.id} className="flex items-start justify-between gap-3 px-4 py-3 text-sm">
                    <div>
                      <p className="font-medium">Level {s.level}: {ROLE_LABEL[s.approver_role]}</p>
                      {s.decided_by && <p className="text-ink-soft">{s.decided_by.name}, {dateTime(s.decided_at)}</p>}
                      {s.approver && !s.decided_by && <p className="text-ink-soft">Assigned to {s.approver.name}</p>}
                      {s.comment && <p className="mt-1 text-ink-soft italic">“{s.comment}”</p>}
                    </div>
                    <Status value={s.status} />
                  </li>
                ))}
              </ol>
            )}
          </Sheet>
          <History type="Requisition" id={r.id} />
        </div>
      </div>

      <DecisionDialog
        decision={decision}
        busy={act.isPending}
        error={act.error}
        onClose={() => setDecision(null)}
        onConfirm={(comment) => act.mutate({ action: decision!, comment })}
        req={r}
      />
      {converting && (
        <ConvertDialog
          req={r}
          onClose={() => setConverting(false)}
          onDone={(po) => {
            qc.invalidateQueries({ queryKey: ['requisition', id] })
            navigate(`/purchase-orders/${po.id}`)
          }}
        />
      )}
    </>
  )
}

function DecisionDialog({
  decision, busy, error, onClose, onConfirm, req,
}: {
  decision: 'approve' | 'reject' | null
  busy: boolean
  error: unknown
  onClose: () => void
  onConfirm: (comment: string) => void
  req: Req
}) {
  const [comment, setComment] = useState('')
  const rejecting = decision === 'reject'
  return (
    <Dialog open={!!decision} onClose={onClose} title={rejecting ? `Reject ${req.number}` : `Approve ${req.number}`}>
      <form className="space-y-4" onSubmit={(e: FormEvent) => { e.preventDefault(); onConfirm(comment) }}>
        <p className="text-sm text-ink-soft">
          {req.title}, {money(req.total_amount, req.currency)} for {req.requester.name}.
        </p>
        <ErrorNote error={error} />
        <Field label={rejecting ? 'Reason (required)' : 'Comment (optional)'}>
          <textarea className="field min-h-20" required={rejecting} value={comment} onChange={(e) => setComment(e.target.value)} autoFocus />
        </Field>
        <div className="flex justify-end gap-2">
          <button type="button" className="btn-quiet" onClick={onClose}>Back</button>
          <button className={rejecting ? 'btn-reject' : 'btn-approve'} disabled={busy}>{rejecting ? 'Reject' : 'Approve'}</button>
        </div>
      </form>
    </Dialog>
  )
}

function ConvertDialog({ req, onClose, onDone }: { req: Req; onClose: () => void; onDone: (po: PurchaseOrderDetail) => void }) {
  const [supplierId, setSupplierId] = useState(req.supplier_id ? String(req.supplier_id) : '')
  const [expectedOn, setExpectedOn] = useState(req.needed_by ?? '')
  const suppliers = useQuery({
    queryKey: ['suppliers', 'active'],
    queryFn: () => api.page<Supplier>('/suppliers', { active: true, per_page: 100 }),
  })
  const issue = useMutation({
    mutationFn: () => api.post<PurchaseOrderDetail>('/purchase_orders', {
      requisition_id: req.id, supplier_id: supplierId, expected_on: expectedOn || null,
    }),
    onSuccess: onDone,
  })
  return (
    <Dialog open onClose={onClose} title={`Issue a purchase order for ${req.number}`}>
      <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); issue.mutate() }}>
        <ErrorNote error={issue.error} />
        <Field label="Supplier">
          <select className="field" required value={supplierId} onChange={(e) => setSupplierId(e.target.value)}>
            <option value="">Choose a supplier</option>
            {suppliers.data?.items.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </Field>
        <Field label="Expected delivery">
          <input className="field" type="date" value={expectedOn} onChange={(e) => setExpectedOn(e.target.value)} />
        </Field>
        <p className="text-sm text-ink-soft">All {req.lines.length} items and prices are copied from the requisition.</p>
        <div className="flex justify-end gap-2">
          <button type="button" className="btn-quiet" onClick={onClose}>Back</button>
          <button className="btn-primary" disabled={issue.isPending}>Issue purchase order</button>
        </div>
      </form>
    </Dialog>
  )
}
