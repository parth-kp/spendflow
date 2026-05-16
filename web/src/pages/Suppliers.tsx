import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { useAuth } from '../auth'
import { Dialog } from '../components/Dialog'
import { Empty, ErrorNote, Field, Loading, PageHeader, Pagination, Sheet } from '../components/ui'
import { api } from '../lib/api'
import type { Supplier } from '../lib/types'
import { useListParams } from '../lib/useListParams'

export function Suppliers() {
  const { can } = useAuth()
  const { values, page, set } = useListParams(['q'])
  const [editing, setEditing] = useState<Partial<Supplier> | null>(null)
  const query = { ...values, page }
  const list = useQuery({
    queryKey: ['suppliers', query],
    queryFn: () => api.page<Supplier>('/suppliers', query),
    placeholderData: keepPreviousData,
  })
  const manage = can('finance', 'admin')

  return (
    <>
      <PageHeader
        title="Suppliers"
        subtitle="Companies you buy from. Invoices are matched to suppliers by name."
        actions={manage && <button className="btn-primary" onClick={() => setEditing({ payment_terms_days: 30, active: true })}>Add supplier</button>}
      />
      <input className="field mb-3 max-w-xs" type="search" placeholder="Search suppliers" aria-label="Search suppliers"
        defaultValue={values.q} onChange={(e) => set({ q: e.target.value })} />
      <Sheet>
        {list.isPending ? <Loading /> : list.data?.items.length === 0 ? <Empty title="No suppliers found" /> : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead><tr><th>Name</th><th>Billing email</th><th>Tax ID</th><th className="num">Payment terms</th><th>Status</th>{manage && <th />}</tr></thead>
              <tbody>
                {list.data?.items.map((s) => (
                  <tr key={s.id}>
                    <td className="font-medium">{s.name}</td>
                    <td className="text-ink-soft">{s.email ?? '—'}</td>
                    <td className="text-ink-soft">{s.tax_id ?? '—'}</td>
                    <td className="num">{s.payment_terms_days} days</td>
                    <td>{s.active ? 'Active' : <span className="text-ink-faint">Inactive</span>}</td>
                    {manage && <td className="text-right"><button className="text-sm text-carbon hover:underline" onClick={() => setEditing(s)}>Edit</button></td>}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {list.data && <Pagination {...list.data} onPage={(p) => set({ page: p })} />}
      </Sheet>
      {editing && <SupplierDialog supplier={editing} onClose={() => setEditing(null)} />}
    </>
  )
}

function SupplierDialog({ supplier, onClose }: { supplier: Partial<Supplier>; onClose: () => void }) {
  const qc = useQueryClient()
  const [form, setForm] = useState(supplier)
  const save = useMutation({
    mutationFn: () =>
      supplier.id ? api.patch(`/suppliers/${supplier.id}`, { supplier: form }) : api.post('/suppliers', { supplier: form }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['suppliers'] })
      onClose()
    },
  })
  const bind = (k: keyof Supplier) => ({
    value: (form[k] as string | number | undefined) ?? '',
    onChange: (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value })),
  })

  return (
    <Dialog open onClose={onClose} title={supplier.id ? `Edit ${supplier.name}` : 'Add a supplier'}>
      <form className="space-y-3" onSubmit={(e: FormEvent) => { e.preventDefault(); save.mutate() }}>
        <ErrorNote error={save.error} />
        <Field label="Name"><input className="field" required {...bind('name')} /></Field>
        <Field label="Billing email"><input className="field" type="email" {...bind('email')} /></Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Tax ID"><input className="field" {...bind('tax_id')} /></Field>
          <Field label="Payment terms (days)"><input className="field" type="number" min="0" max="180" {...bind('payment_terms_days')} /></Field>
        </div>
        <Field label="Address"><input className="field" {...bind('address')} /></Field>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={!!form.active} onChange={(e) => setForm((f) => ({ ...f, active: e.target.checked }))} />
          Active
        </label>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" className="btn-quiet" onClick={onClose}>Back</button>
          <button className="btn-primary" disabled={save.isPending}>Save supplier</button>
        </div>
      </form>
    </Dialog>
  )
}
