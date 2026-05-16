import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Dialog } from '../components/Dialog'
import { DocumentPreview } from '../components/DocumentPreview'
import { History } from '../components/History'
import { InvoiceEditor } from '../components/InvoiceEditor'
import { MatchGrid } from '../components/MatchGrid'
import { Stamp } from '../components/Stamp'
import { ErrorNote, Field, Loading, PageHeader, Sheet, SheetTitle } from '../components/ui'
import { api } from '../lib/api'
import { date, money } from '../lib/format'
import type { InvoiceDetail as Inv, PurchaseOrderDetail } from '../lib/types'

const CHECK_LABELS: Record<string, string> = {
  purchase_order: 'Linked to a purchase order',
  supplier: 'Same supplier as the PO',
  currency: 'Same currency as the PO',
  po_status: 'PO is still open',
  total: 'Total agrees with PO prices and received quantities',
}

const READING = ['uploaded', 'processing']

export function InvoiceDetail() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [editing, setEditing] = useState(false)
  const [dialog, setDialog] = useState<'approve' | 'reject' | 'pay' | null>(null)

  const { data: inv, error, isPending } = useQuery({
    queryKey: ['invoice', id],
    queryFn: () => api.get<Inv>(`/invoices/${id}`),
    refetchInterval: (q) => (q.state.data && READING.includes(q.state.data.status) ? 2000 : false),
  })

  const po = useQuery({
    queryKey: ['purchase_order', String(inv?.purchase_order?.id)],
    queryFn: () => api.get<PurchaseOrderDetail>(`/purchase_orders/${inv!.purchase_order!.id}`),
    enabled: !!inv?.purchase_order,
  })

  const refresh = (data: Inv) => {
    qc.setQueryData(['invoice', id], data)
    qc.invalidateQueries({ queryKey: ['invoices'] })
    qc.invalidateQueries({ queryKey: ['audit', 'Invoice'] })
    qc.invalidateQueries({ queryKey: ['purchase_order'] })
    qc.invalidateQueries({ queryKey: ['dashboard'] })
  }

  const act = useMutation({
    mutationFn: ({ action, body }: { action: string; body?: object }) => api.post<Inv>(`/invoices/${id}/${action}`, body),
    onSuccess: (data) => { refresh(data); setDialog(null) },
  })

  if (isPending) return <Loading />
  if (error) return <ErrorNote error={error} />

  const p = inv.permissions
  const reading = READING.includes(inv.status)
  const confidence = typeof inv.extraction?.confidence === 'number' ? inv.extraction.confidence : null
  const warnings = inv.extraction?.warnings ?? []
  const checks = inv.match_result.checks ?? []
  const currency = inv.currency ?? 'USD'

  return (
    <>
      <PageHeader
        back={{ to: '/invoices', label: 'Invoices' }}
        title={inv.invoice_number ? `Invoice ${inv.invoice_number}` : `Upload #${inv.id}`}
        subtitle={
          <>
            {inv.supplier?.name ?? 'Supplier not identified'}
            {inv.purchase_order && (
              <> against <Link className="text-carbon hover:underline" to={`/purchase-orders/${inv.purchase_order.id}`}>{inv.purchase_order.number}</Link></>
            )}
          </>
        }
        actions={
          <>
            {p.reprocess && <button className="btn-quiet" onClick={() => act.mutate({ action: 'reprocess' })}>Read again</button>}
            {p.update && <button className="btn-quiet" onClick={() => setEditing(true)}>Correct details</button>}
            {p.rematch && <button className="btn-quiet" onClick={() => act.mutate({ action: 'rematch' })}>Re-run match</button>}
            {p.reject && <button className="btn-reject" onClick={() => setDialog('reject')}>Reject</button>}
            {p.approve && <button className="btn-approve" onClick={() => setDialog('approve')}>Approve for payment</button>}
            {p.pay && <button className="btn-primary" onClick={() => setDialog('pay')}>Mark as paid</button>}
          </>
        }
      />
      {act.error && !dialog && <div className="mb-4"><ErrorNote error={act.error} /></div>}

      {reading && (
        <div className="mb-6 flex items-center gap-3 rounded-lg border border-carbon/30 bg-carbon-tint px-4 py-3 text-sm text-carbon" role="status">
          <span className="size-2 animate-pulse rounded-full bg-carbon" aria-hidden />
          Reading the invoice and looking for its purchase order. This usually takes a few seconds.
        </div>
      )}
      {inv.status === 'extraction_failed' && (
        <div className="mb-6 rounded-lg border border-reject/30 bg-reject-tint px-4 py-3 text-sm text-reject">
          <p className="font-semibold">SpendFlow couldn't read this document.</p>
          <p>{inv.extraction_error} Try reading it again, or enter the details by hand.</p>
        </div>
      )}

      <div className="grid gap-6 xl:grid-cols-[1fr_380px]">
        <div className="space-y-6">
          <Sheet>
            <div className="flex flex-wrap items-start justify-between gap-4 p-4">
              <dl className="grid grid-cols-2 gap-x-8 gap-y-3 text-sm sm:grid-cols-4">
                <div><dt className="text-ink-soft">Total</dt><dd className="text-xl font-bold tabular-nums">{money(inv.total_amount, currency)}</dd></div>
                <div><dt className="text-ink-soft">Invoice date</dt><dd>{date(inv.invoice_date)}</dd></div>
                <div><dt className="text-ink-soft">Due</dt><dd>{date(inv.due_date)}</dd></div>
                <div><dt className="text-ink-soft">Tax</dt><dd className="tabular-nums">{money(inv.tax_amount, currency)}</dd></div>
              </dl>
              <Stamp value={inv.status} note={inv.approved_by ? `by ${inv.approved_by.name}` : undefined} />
            </div>
            {confidence !== null && (
              <div className="flex flex-wrap gap-x-6 gap-y-1 border-t border-rule px-4 py-2.5 text-xs text-ink-soft">
                {inv.extraction?.source && <span>Read by {String(inv.extraction.source).replace('openrouter:', '')}</span>}
                {confidence !== null && <span>Reader confidence {(confidence * 100).toFixed(0)}%</span>}
              </div>
            )}
            {warnings.length > 0 && (
              <ul className="border-t border-rule px-4 py-2.5 text-sm text-variance">
                {warnings.map((w) => <li key={w}>{w}</li>)}
              </ul>
            )}
          </Sheet>

          {checks.length > 0 && (
            <Sheet>
              <SheetTitle>3-way match: purchase order, delivery, invoice</SheetTitle>
              <ul className="grid gap-x-6 gap-y-1.5 px-4 py-3 text-sm sm:grid-cols-2">
                {checks.map((c) => (
                  <li key={c.name} className={`flex gap-2 ${c.passed ? '' : 'text-variance'}`}>
                    <span aria-hidden className={c.passed ? 'text-approve' : ''}>{c.passed ? '✓' : '!'}</span>
                    <span>{c.passed ? CHECK_LABELS[c.name] ?? c.name : c.message}</span>
                  </li>
                ))}
              </ul>
              <MatchGrid invoice={inv} poLines={po.data?.lines ?? []} />
            </Sheet>
          )}
        </div>

        <div className="space-y-6">
          {inv.document && (
            <Sheet className="overflow-hidden">
              <SheetTitle>{inv.document.filename}</SheetTitle>
              <DocumentPreview invoiceId={inv.id} contentType={inv.document.content_type} />
            </Sheet>
          )}
          <History type="Invoice" id={inv.id} />
        </div>
      </div>

      {editing && (
        <Dialog open onClose={() => setEditing(false)} title="Correct invoice details">
          <InvoiceEditor invoice={inv} onCancel={() => setEditing(false)} onSaved={(data) => { refresh(data); setEditing(false) }} />
        </Dialog>
      )}

      <ActionDialog
        kind={dialog}
        invoice={inv}
        busy={act.isPending}
        error={act.error}
        onClose={() => { setDialog(null); act.reset() }}
        onConfirm={(text) => {
          if (dialog === 'pay') act.mutate({ action: 'pay', body: { reference: text } })
          else act.mutate({ action: dialog!, body: { comment: text } })
        }}
      />
    </>
  )
}

function ActionDialog({
  kind, invoice, busy, error, onClose, onConfirm,
}: {
  kind: 'approve' | 'reject' | 'pay' | null
  invoice: Inv
  busy: boolean
  error: unknown
  onClose: () => void
  onConfirm: (text: string) => void
}) {
  const [text, setText] = useState('')
  if (!kind) return null
  const override = kind === 'approve' && invoice.status === 'exception'
  const copy = {
    approve: {
      title: override ? 'Approve despite match exceptions' : 'Approve for payment',
      label: override ? 'Why is it OK to pay this? (required)' : 'Comment (optional)',
      required: override,
      button: 'Approve for payment',
    },
    reject: { title: 'Reject invoice', label: 'Reason (required, shared with the audit log)', required: true, button: 'Reject' },
    pay: { title: 'Mark as paid', label: 'Payment reference', required: false, button: 'Mark as paid' },
  }[kind]

  return (
    <Dialog open onClose={onClose} title={copy.title}>
      <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); onConfirm(text) }}>
        <p className="text-sm text-ink-soft">
          {invoice.supplier?.name}, {money(invoice.total_amount, invoice.currency ?? 'USD')}
        </p>
        <ErrorNote error={error} />
        <Field label={copy.label}>
          <textarea className="field min-h-20" required={copy.required} value={text} onChange={(e) => setText(e.target.value)} autoFocus />
        </Field>
        <div className="flex justify-end gap-2">
          <button type="button" className="btn-quiet" onClick={onClose}>Back</button>
          <button className={kind === 'reject' ? 'btn-reject' : kind === 'approve' ? 'btn-approve' : 'btn-primary'} disabled={busy}>
            {copy.button}
          </button>
        </div>
      </form>
    </Dialog>
  )
}
