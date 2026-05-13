import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Dialog } from '../components/Dialog'
import { History } from '../components/History'
import { Stamp } from '../components/Stamp'
import { ErrorNote, Field, Loading, PageHeader, Sheet, SheetTitle } from '../components/ui'
import { api } from '../lib/api'
import { date, money, qty } from '../lib/format'
import type { PurchaseOrderDetail as Po } from '../lib/types'

export function PurchaseOrderDetail() {
  const { id } = useParams()
  const qc = useQueryClient()
  const [receiving, setReceiving] = useState(false)
  const { data: po, error, isPending } = useQuery({
    queryKey: ['purchase_order', id],
    queryFn: () => api.get<Po>(`/purchase_orders/${id}`),
  })

  const act = useMutation({
    mutationFn: (action: 'close' | 'cancel') => api.post<Po>(`/purchase_orders/${id}/${action}`),
    onSuccess: (data) => {
      qc.setQueryData(['purchase_order', id], data)
      qc.invalidateQueries({ queryKey: ['purchase_orders'] })
      qc.invalidateQueries({ queryKey: ['audit', 'PurchaseOrder'] })
    },
  })

  if (isPending) return <Loading />
  if (error) return <ErrorNote error={error} />

  return (
    <>
      <PageHeader
        back={{ to: '/purchase-orders', label: 'Purchase orders' }}
        title={`${po.number} to ${po.supplier.name}`}
        subtitle={po.requisition && (
          <>From <Link className="text-carbon hover:underline" to={`/requisitions/${po.requisition.id}`}>{po.requisition.number}</Link>, {po.requisition.title}</>
        )}
        actions={
          <>
            {po.permissions.cancel && <button className="btn-reject" onClick={() => confirm('Cancel this purchase order?') && act.mutate('cancel')}>Cancel order</button>}
            {po.permissions.close && <button className="btn-quiet" onClick={() => act.mutate('close')}>Close order</button>}
            {po.permissions.receive && <button className="btn-primary" onClick={() => setReceiving(true)}>Record delivery</button>}
          </>
        }
      />
      {act.error && <div className="mb-4"><ErrorNote error={act.error} /></div>}

      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <div className="space-y-6">
          <Sheet>
            <div className="flex flex-wrap items-start justify-between gap-4 p-4">
              <dl className="grid grid-cols-2 gap-x-8 gap-y-3 text-sm sm:grid-cols-3">
                <div><dt className="text-ink-soft">Total</dt><dd className="text-xl font-bold tabular-nums">{money(po.total_amount, po.currency)}</dd></div>
                <div><dt className="text-ink-soft">Issued</dt><dd>{date(po.issued_at)}</dd></div>
                <div><dt className="text-ink-soft">Expected</dt><dd>{date(po.expected_on)}</dd></div>
              </dl>
              <Stamp value={po.status} />
            </div>
          </Sheet>

          <Sheet>
            <SheetTitle>Lines</SheetTitle>
            <div className="overflow-x-auto">
              <table className="table">
                <thead>
                  <tr><th>#</th><th>Description</th><th className="num">Ordered</th><th className="num">Received</th><th className="num">Invoiced</th><th className="num">Unit price</th><th className="num">Amount</th></tr>
                </thead>
                <tbody>
                  {po.lines.map((l) => {
                    const short = Number(l.received_quantity) < Number(l.quantity)
                    return (
                      <tr key={l.id}>
                        <td className="text-ink-faint">{l.line_no}</td>
                        <td>{l.description}</td>
                        <td className="num">{qty(l.quantity)} {l.unit}</td>
                        <td className={`num ${short ? 'text-variance' : 'text-approve'}`}>{qty(l.received_quantity)}</td>
                        <td className="num">{qty(l.invoiced_quantity)}</td>
                        <td className="num">{money(l.unit_price, po.currency)}</td>
                        <td className="num font-medium">{money(l.amount, po.currency)}</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </Sheet>

          <Sheet>
            <SheetTitle>Deliveries</SheetTitle>
            {po.receipts.length === 0 ? (
              <p className="px-4 py-4 text-sm text-ink-soft">Nothing received yet. Record a delivery when goods arrive so the invoice can be matched.</p>
            ) : (
              <ul className="divide-y divide-rule/70">
                {po.receipts.map((r) => (
                  <li key={r.id} className="px-4 py-3 text-sm">
                    <p className="font-medium">{r.number}, received {date(r.received_on)} by {r.received_by.name}</p>
                    <p className="text-ink-soft">
                      {r.lines.map((gl) => {
                        const line = po.lines.find((l) => l.id === gl.purchase_order_line_id)
                        return `${qty(gl.quantity)} × ${line?.description ?? 'item'}`
                      }).join('; ')}
                    </p>
                    {r.notes && <p className="mt-1 text-ink-soft italic">{r.notes}</p>}
                  </li>
                ))}
              </ul>
            )}
          </Sheet>
        </div>
        <History type="PurchaseOrder" id={po.id} />
      </div>

      {receiving && <ReceiveDialog po={po} onClose={() => setReceiving(false)} />}
    </>
  )
}

function ReceiveDialog({ po, onClose }: { po: Po; onClose: () => void }) {
  const qc = useQueryClient()
  const open = po.lines.filter((l) => Number(l.received_quantity) < Number(l.quantity))
  const [quantities, setQuantities] = useState<Record<number, string>>(
    Object.fromEntries(open.map((l) => [l.id, String(Number(l.quantity) - Number(l.received_quantity))])),
  )
  const [notes, setNotes] = useState('')
  const receive = useMutation({
    mutationFn: () =>
      api.post<Po>(`/purchase_orders/${po.id}/receive`, {
        notes,
        lines: Object.entries(quantities)
          .filter(([, q]) => Number(q) > 0)
          .map(([id, quantity]) => ({ purchase_order_line_id: Number(id), quantity })),
      }),
    onSuccess: (data) => {
      qc.setQueryData(['purchase_order', String(po.id)], data)
      qc.invalidateQueries({ queryKey: ['audit', 'PurchaseOrder'] })
      qc.invalidateQueries({ queryKey: ['purchase_orders'] })
      onClose()
    },
  })

  return (
    <Dialog open onClose={onClose} title={`Record a delivery for ${po.number}`}>
      <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); receive.mutate() }}>
        <ErrorNote error={receive.error} />
        <p className="text-sm text-ink-soft">Enter what actually arrived. Leave a line at 0 if it hasn't come yet.</p>
        <table className="table">
          <thead><tr><th>Item</th><th className="num">Still due</th><th className="w-28">Received now</th></tr></thead>
          <tbody>
            {open.map((l) => (
              <tr key={l.id}>
                <td>{l.description}</td>
                <td className="num">{qty(Number(l.quantity) - Number(l.received_quantity))}</td>
                <td>
                  <input className="field" type="number" min="0" step="any" aria-label={`Received quantity for ${l.description}`}
                    value={quantities[l.id] ?? ''} onChange={(e) => setQuantities((q) => ({ ...q, [l.id]: e.target.value }))} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <Field label="Notes (optional)">
          <input className="field" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="e.g. 2 boxes damaged, returned" />
        </Field>
        <div className="flex justify-end gap-2">
          <button type="button" className="btn-quiet" onClick={onClose}>Back</button>
          <button className="btn-primary" disabled={receive.isPending}>Record delivery</button>
        </div>
      </form>
    </Dialog>
  )
}
