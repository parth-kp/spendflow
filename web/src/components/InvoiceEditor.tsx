import { useMutation, useQuery } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api } from '../lib/api'
import { money } from '../lib/format'
import type { InvoiceDetail, PurchaseOrder, Supplier } from '../lib/types'
import { ErrorNote, Field } from './ui'

interface Line {
  id?: number
  description: string
  quantity: string
  unit_price: string
  _destroy?: boolean
}

/** Used both to enter an invoice by hand and to correct what the reader extracted. */
export function InvoiceEditor({
  invoice,
  onSaved,
  onCancel,
}: {
  invoice?: InvoiceDetail
  onSaved: (inv: InvoiceDetail) => void
  onCancel: () => void
}) {
  const [supplierId, setSupplierId] = useState(invoice?.supplier ? String(invoice.supplier.id) : '')
  const [poId, setPoId] = useState(invoice?.purchase_order ? String(invoice.purchase_order.id) : '')
  const [number, setNumber] = useState(invoice?.invoice_number ?? '')
  const [invoiceDate, setInvoiceDate] = useState(invoice?.invoice_date ?? '')
  const [dueDate, setDueDate] = useState(invoice?.due_date ?? '')
  const [tax, setTax] = useState(invoice?.tax_amount ?? '0')
  const [lines, setLines] = useState<Line[]>(
    invoice?.lines.length
      ? invoice.lines.map((l) => ({ id: l.id, description: l.description, quantity: l.quantity, unit_price: l.unit_price }))
      : [{ description: '', quantity: '1', unit_price: '' }],
  )

  const suppliers = useQuery({
    queryKey: ['suppliers', 'active'],
    queryFn: () => api.page<Supplier>('/suppliers', { active: true, per_page: 100 }),
  })
  const pos = useQuery({
    queryKey: ['purchase_orders', { supplier_id: supplierId }],
    queryFn: () => api.page<PurchaseOrder>('/purchase_orders', { supplier_id: supplierId, per_page: 50 }),
    enabled: !!supplierId,
  })

  const save = useMutation({
    mutationFn: () => {
      const body = {
        invoice: {
          supplier_id: supplierId || null,
          purchase_order_id: poId || null,
          invoice_number: number,
          invoice_date: invoiceDate || null,
          due_date: dueDate || null,
          tax_amount: tax || 0,
          lines_attributes: lines
            .filter((l) => l.id || !l._destroy)
            .map(({ id, description, quantity, unit_price, _destroy }) => ({
              id, description, quantity, unit_price, _destroy, ...(id && !_destroy ? { amount: Number(quantity) * Number(unit_price) } : {}),
            })),
        },
      }
      return invoice
        ? api.patch<InvoiceDetail>(`/invoices/${invoice.id}`, body)
        : api.post<InvoiceDetail>('/invoices', body)
    },
    onSuccess: onSaved,
  })

  const visible = lines.filter((l) => !l._destroy)
  const subtotal = visible.reduce((s, l) => s + Number(l.quantity || 0) * Number(l.unit_price || 0), 0)
  const currency = invoice?.currency ?? 'USD'
  const update = (i: number, patch: Partial<Line>) => setLines((ls) => ls.map((l, idx) => (idx === i ? { ...l, ...patch } : l)))

  return (
    <form className="space-y-4" onSubmit={(e: FormEvent) => { e.preventDefault(); save.mutate() }}>
      <ErrorNote error={save.error} />
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Supplier">
          <select className="field" value={supplierId} onChange={(e) => { setSupplierId(e.target.value); setPoId('') }}>
            <option value="">Unknown</option>
            {suppliers.data?.items.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </Field>
        <Field label="Purchase order">
          <select className="field" value={poId} onChange={(e) => setPoId(e.target.value)} disabled={!supplierId}>
            <option value="">Not linked</option>
            {pos.data?.items.map((p) => <option key={p.id} value={p.id}>{p.number}, {money(p.total_amount, p.currency)}</option>)}
            {invoice?.purchase_order && !pos.data?.items.some((p) => p.id === invoice.purchase_order!.id) && (
              <option value={invoice.purchase_order.id}>{invoice.purchase_order.number}</option>
            )}
          </select>
        </Field>
        <Field label="Invoice number">
          <input className="field" value={number} onChange={(e) => setNumber(e.target.value)} />
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Invoice date"><input className="field" type="date" value={invoiceDate} onChange={(e) => setInvoiceDate(e.target.value)} /></Field>
          <Field label="Due date"><input className="field" type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} /></Field>
        </div>
      </div>

      <table className="table">
        <thead><tr><th>Description</th><th className="w-24">Qty</th><th className="w-32">Unit price</th><th className="w-8" /></tr></thead>
        <tbody>
          {lines.map((l, i) =>
            l._destroy ? null : (
              <tr key={l.id ?? `n${i}`}>
                <td><input className="field" required aria-label="Description" value={l.description} onChange={(e) => update(i, { description: e.target.value })} /></td>
                <td><input className="field" required type="number" step="any" min="0" aria-label="Quantity" value={l.quantity} onChange={(e) => update(i, { quantity: e.target.value })} /></td>
                <td><input className="field" required type="number" step="0.01" min="0" aria-label="Unit price" value={l.unit_price} onChange={(e) => update(i, { unit_price: e.target.value })} /></td>
                <td>
                  <button type="button" aria-label="Remove line" className="px-1 pt-2 text-ink-faint hover:text-reject"
                    onClick={() => setLines((ls) => (ls[i].id ? ls.map((x, idx) => (idx === i ? { ...x, _destroy: true } : x)) : ls.filter((_, idx) => idx !== i)))}>
                    ✕
                  </button>
                </td>
              </tr>
            ),
          )}
        </tbody>
      </table>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <button type="button" className="btn-quiet" onClick={() => setLines((l) => [...l, { description: '', quantity: '1', unit_price: '' }])}>Add line</button>
        <div className="flex items-end gap-3 text-sm">
          <Field label="Tax"><input className="field w-28" type="number" step="0.01" min="0" value={tax} onChange={(e) => setTax(e.target.value)} /></Field>
          <p className="pb-2 font-semibold tabular-nums">Total {money(subtotal + Number(tax || 0), currency)}</p>
        </div>
      </div>
      <div className="flex justify-end gap-2 border-t border-rule pt-4">
        <button type="button" className="btn-quiet" onClick={onCancel}>Back</button>
        <button className="btn-primary" disabled={save.isPending}>{invoice ? 'Save and re-match' : 'Save and match'}</button>
      </div>
    </form>
  )
}
