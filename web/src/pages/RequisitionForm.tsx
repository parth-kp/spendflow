import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState, type FormEvent } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../auth'
import { ErrorNote, Field, Loading, PageHeader, Sheet, SheetTitle } from '../components/ui'
import { api } from '../lib/api'
import { money } from '../lib/format'
import type { ApprovalRule, RequisitionDetail, RequisitionLine, Supplier } from '../lib/types'

const blankLine = (): RequisitionLine => ({ description: '', quantity: '1', unit: 'ea', unit_price: '' })

export function RequisitionForm() {
  const { id } = useParams()
  const editing = !!id
  const navigate = useNavigate()
  const qc = useQueryClient()
  const { user } = useAuth()

  const existing = useQuery({
    queryKey: ['requisition', id],
    queryFn: () => api.get<RequisitionDetail>(`/requisitions/${id}`),
    enabled: editing,
  })
  const suppliers = useQuery({
    queryKey: ['suppliers', 'active'],
    queryFn: () => api.page<Supplier>('/suppliers', { active: true, per_page: 100 }),
  })

  const [title, setTitle] = useState('')
  const [justification, setJustification] = useState('')
  const [neededBy, setNeededBy] = useState('')
  const [supplierId, setSupplierId] = useState('')
  const [lines, setLines] = useState<RequisitionLine[]>([blankLine()])

  useEffect(() => {
    const r = existing.data
    if (!r) return
    setTitle(r.title)
    setJustification(r.justification ?? '')
    setNeededBy(r.needed_by ?? '')
    setSupplierId(r.supplier_id ? String(r.supplier_id) : '')
    setLines(r.lines.length ? r.lines : [blankLine()])
  }, [existing.data])

  const visible = lines.filter((l) => !l._destroy)
  const total = visible.reduce((sum, l) => sum + Number(l.quantity || 0) * Number(l.unit_price || 0), 0)

  const chain = useQuery({
    queryKey: ['approval_rules', 'preview', Math.round(total), user!.department?.id],
    queryFn: () => api.get<ApprovalRule[]>('/approval_rules/preview', { amount: total, department_id: user!.department?.id }),
    enabled: total > 0,
  })

  const save = useMutation({
    mutationFn: (submitAfter: boolean) => {
      const body = {
        requisition: {
          title,
          justification,
          needed_by: neededBy || null,
          supplier_id: supplierId || null,
          lines_attributes: lines
            .filter((l) => l.id || !l._destroy)
            .map(({ id, description, quantity, unit, unit_price, _destroy }) => ({ id, description, quantity, unit, unit_price, _destroy })),
        },
      }
      const req = editing
        ? api.patch<RequisitionDetail>(`/requisitions/${id}`, body)
        : api.post<RequisitionDetail>('/requisitions', body)
      return req.then((r) => (submitAfter ? api.post<RequisitionDetail>(`/requisitions/${r.id}/submit`) : r))
    },
    onSuccess: (r) => {
      qc.invalidateQueries({ queryKey: ['requisitions'] })
      qc.setQueryData(['requisition', String(r.id)], r)
      navigate(`/requisitions/${r.id}`)
    },
  })

  function update(i: number, patch: Partial<RequisitionLine>) {
    setLines((ls) => ls.map((l, idx) => (idx === i ? { ...l, ...patch } : l)))
  }

  function remove(i: number) {
    setLines((ls) => (ls[i].id ? ls.map((l, idx) => (idx === i ? { ...l, _destroy: true } : l)) : ls.filter((_, idx) => idx !== i)))
  }

  function submit(e: FormEvent, andSubmit: boolean) {
    e.preventDefault()
    save.mutate(andSubmit)
  }

  if (editing && existing.isPending) return <Loading />
  const currency = existing.data?.currency ?? user!.company.currency

  return (
    <form onSubmit={(e) => submit(e, true)}>
      <PageHeader
        title={editing ? `Edit ${existing.data?.number}` : 'New requisition'}
        subtitle="Describe what you need and why. Your manager is asked first; larger amounts also go to finance."
        back={{ to: editing ? `/requisitions/${id}` : '/requisitions', label: editing ? 'Back to requisition' : 'Requisitions' }}
      />
      <div className="grid gap-6 lg:grid-cols-[1fr_280px]">
        <div className="space-y-6">
          <Sheet className="space-y-4 p-4">
            <ErrorNote error={save.error} />
            <Field label="What do you need?">
              <input className="field" required value={title} onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Laptops for three new engineers" />
            </Field>
            <Field label="Why is it needed?" hint="Approvers see this. A sentence or two is enough.">
              <textarea className="field min-h-20" value={justification} onChange={(e) => setJustification(e.target.value)} />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Preferred supplier">
                <select className="field" value={supplierId} onChange={(e) => setSupplierId(e.target.value)}>
                  <option value="">No preference</option>
                  {suppliers.data?.items.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              </Field>
              <Field label="Needed by">
                <input className="field" type="date" value={neededBy} onChange={(e) => setNeededBy(e.target.value)} />
              </Field>
            </div>
          </Sheet>

          <Sheet>
            <SheetTitle aside={<button type="button" className="btn-quiet" onClick={() => setLines((l) => [...l, blankLine()])}>Add item</button>}>
              Items
            </SheetTitle>
            <div className="overflow-x-auto">
              <table className="table">
                <thead>
                  <tr>
                    <th>Description</th>
                    <th className="w-24">Qty</th>
                    <th className="w-20">Unit</th>
                    <th className="w-32">Unit price</th>
                    <th className="num w-28">Amount</th>
                    <th className="w-10"><span className="sr-only">Remove</span></th>
                  </tr>
                </thead>
                <tbody>
                  {lines.map((l, i) =>
                    l._destroy ? null : (
                      <tr key={l.id ?? `new-${i}`}>
                        <td><input className="field" required aria-label="Description" value={l.description}
                          onChange={(e) => update(i, { description: e.target.value })} /></td>
                        <td><input className="field" required type="number" min="0.001" step="any" aria-label="Quantity"
                          value={l.quantity} onChange={(e) => update(i, { quantity: e.target.value })} /></td>
                        <td><input className="field" aria-label="Unit" value={l.unit} onChange={(e) => update(i, { unit: e.target.value })} /></td>
                        <td><input className="field" required type="number" min="0" step="0.01" aria-label="Unit price"
                          value={l.unit_price} onChange={(e) => update(i, { unit_price: e.target.value })} /></td>
                        <td className="num pt-4 font-medium">{money(Number(l.quantity || 0) * Number(l.unit_price || 0), currency)}</td>
                        <td>
                          <button type="button" className="px-2 pt-2 text-ink-faint hover:text-reject disabled:opacity-30"
                            onClick={() => remove(i)} disabled={visible.length === 1} aria-label={`Remove ${l.description || 'item'}`}>
                            ✕
                          </button>
                        </td>
                      </tr>
                    ),
                  )}
                </tbody>
              </table>
            </div>
          </Sheet>
        </div>

        <aside className="space-y-4 lg:sticky lg:top-20 lg:self-start">
          <Sheet className="p-4">
            <p className="text-sm text-ink-soft">Total</p>
            <p className="text-3xl font-bold tabular-nums">{money(total, currency)}</p>
            {chain.data && (
              <div className="mt-4 border-t border-rule pt-3 text-sm">
                <p className="mb-1 text-ink-soft">This will need approval from</p>
                <ol className="list-decimal pl-5">
                  {chain.data.map((r) => <li key={r.id}>{r.name}</li>)}
                </ol>
              </div>
            )}
            <div className="mt-4 flex flex-col gap-2">
              <button className="btn-primary" disabled={save.isPending}>Submit for approval</button>
              <button type="button" className="btn-quiet" disabled={save.isPending} onClick={(e) => submit(e, false)}>
                Save as draft
              </button>
            </div>
          </Sheet>
        </aside>
      </div>
    </form>
  )
}
