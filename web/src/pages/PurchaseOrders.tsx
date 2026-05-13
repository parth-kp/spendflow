import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Link, useNavigate } from 'react-router-dom'
import { Status } from '../components/Stamp'
import { Empty, ErrorNote, Loading, PageHeader, Pagination, Sheet } from '../components/ui'
import { api } from '../lib/api'
import { date, money } from '../lib/format'
import type { PurchaseOrder } from '../lib/types'
import { useListParams } from '../lib/useListParams'

const STATUSES = ['', 'issued', 'partially_received', 'received', 'closed', 'cancelled']

export function PurchaseOrders() {
  const navigate = useNavigate()
  const { values, page, set } = useListParams(['status'])
  const query = { ...values, page }
  const list = useQuery({
    queryKey: ['purchase_orders', query],
    queryFn: () => api.page<PurchaseOrder>('/purchase_orders', query),
    placeholderData: keepPreviousData,
  })

  return (
    <>
      <PageHeader title="Purchase orders" subtitle="Orders sent to suppliers. Record what arrives here so invoices can be matched." />
      <div className="mb-3">
        <select className="field w-auto" value={values.status} onChange={(e) => set({ status: e.target.value })} aria-label="Filter by status">
          {STATUSES.map((s) => <option key={s} value={s}>{s ? s.replace('_', ' ') : 'Any status'}</option>)}
        </select>
      </div>
      <Sheet>
        {list.error && <div className="p-4"><ErrorNote error={list.error} /></div>}
        {list.isPending ? (
          <Loading />
        ) : list.data?.items.length === 0 ? (
          <Empty title="No purchase orders yet">Approved requisitions become purchase orders when finance issues them.</Empty>
        ) : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr><th>Number</th><th>Supplier</th><th>From requisition</th><th>Issued</th><th>Expected</th><th className="num">Total</th><th>Status</th></tr>
              </thead>
              <tbody>
                {list.data?.items.map((po) => (
                  <tr key={po.id} className="cursor-pointer" onClick={() => navigate(`/purchase-orders/${po.id}`)}>
                    <td><Link to={`/purchase-orders/${po.id}`} className="font-medium text-carbon hover:underline">{po.number}</Link></td>
                    <td>{po.supplier.name}</td>
                    <td className="text-ink-soft">{po.requisition ? `${po.requisition.number}, ${po.requisition.title}` : '—'}</td>
                    <td className="whitespace-nowrap">{date(po.issued_at)}</td>
                    <td className="whitespace-nowrap">{date(po.expected_on)}</td>
                    <td className="num font-medium">{money(po.total_amount, po.currency)}</td>
                    <td><Status value={po.status} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {list.data && <Pagination {...list.data} onPage={(p) => set({ page: p })} />}
      </Sheet>
    </>
  )
}
