import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { Empty, Loading, PageHeader, Pagination, Sheet } from '../components/ui'
import { api } from '../lib/api'
import { dateTime, humanize } from '../lib/format'
import type { AuditEvent } from '../lib/types'
import { useListParams } from '../lib/useListParams'

const PATHS: Record<string, string> = { Requisition: '/requisitions', PurchaseOrder: '/purchase-orders', Invoice: '/invoices' }
const ACTIONS = ['', 'submitted', 'step_approved', 'approved', 'rejected', 'converted_to_po', 'issued', 'goods_received', 'uploaded', 'extracted', 'matched', 'paid']

export function AuditLog() {
  const { values, page, set } = useListParams(['type', 'action_name'])
  const query = { ...values, page, per_page: 50 }
  const list = useQuery({
    queryKey: ['audit', 'all', query],
    queryFn: () => api.page<AuditEvent>('/audit_events', query),
    placeholderData: keepPreviousData,
  })

  return (
    <>
      <PageHeader title="Audit log" subtitle="Every approval, rejection, receipt and payment, with who did it and when. Entries can't be edited or deleted." />
      <div className="mb-3 flex flex-wrap gap-2">
        <select className="field w-auto" value={values.type} onChange={(e) => set({ type: e.target.value })} aria-label="Document type">
          <option value="">All documents</option>
          <option value="Requisition">Requisitions</option>
          <option value="PurchaseOrder">Purchase orders</option>
          <option value="Invoice">Invoices</option>
        </select>
        <select className="field w-auto" value={values.action_name} onChange={(e) => set({ action_name: e.target.value })} aria-label="Action">
          {ACTIONS.map((a) => <option key={a} value={a}>{a ? humanize(a) : 'Any action'}</option>)}
        </select>
      </div>
      <Sheet>
        {list.isPending ? <Loading /> : list.data?.items.length === 0 ? <Empty title="No matching events" /> : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead><tr><th>When</th><th>Who</th><th>Action</th><th>Document</th><th>Details</th></tr></thead>
              <tbody>
                {list.data?.items.map((e) => {
                  const m = e.metadata as Record<string, unknown>
                  const details = Object.entries(m)
                    .filter(([, v]) => v !== null && v !== '' && !(Array.isArray(v) && v.length === 0))
                    .map(([k, v]) => `${humanize(k)}: ${typeof v === 'object' ? JSON.stringify(v) : String(v)}`)
                    .join('; ')
                  return (
                    <tr key={e.id}>
                      <td className="whitespace-nowrap text-ink-soft">{dateTime(e.created_at)}</td>
                      <td className="whitespace-nowrap">{e.actor ? `${e.actor.name} (${e.actor.role})` : <span className="text-ink-faint">System</span>}</td>
                      <td className="whitespace-nowrap font-medium">{humanize(e.action)}</td>
                      <td className="whitespace-nowrap">
                        <Link className="text-carbon hover:underline" to={`${PATHS[e.auditable.type]}/${e.auditable.id}`}>
                          {e.auditable.label ?? `${e.auditable.type} #${e.auditable.id}`}
                        </Link>
                      </td>
                      <td className="max-w-md text-xs text-ink-soft">{details}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
        {list.data && <Pagination {...list.data} onPage={(p) => set({ page: p })} />}
      </Sheet>
    </>
  )
}
