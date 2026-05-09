import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Link, useNavigate } from 'react-router-dom'
import { Status } from '../components/Stamp'
import { Empty, ErrorNote, Loading, PageHeader, Pagination, Sheet } from '../components/ui'
import { api } from '../lib/api'
import { date, money } from '../lib/format'
import type { Requisition } from '../lib/types'
import { useListParams } from '../lib/useListParams'

const STATUSES = ['', 'draft', 'pending_approval', 'approved', 'ordered', 'rejected', 'cancelled']

export function Requisitions() {
  const navigate = useNavigate()
  const { values, page, set } = useListParams(['status', 'q', 'mine'])
  const query = { ...values, page }
  const list = useQuery({
    queryKey: ['requisitions', query],
    queryFn: () => api.page<Requisition>('/requisitions', query),
    placeholderData: keepPreviousData,
  })

  return (
    <>
      <PageHeader
        title="Requisitions"
        subtitle="Requests to buy something. Each one goes through approval before it becomes a purchase order."
        actions={<Link to="/requisitions/new" className="btn-primary">New requisition</Link>}
      />

      <div className="mb-3 flex flex-wrap items-center gap-2">
        <input
          className="field max-w-xs"
          type="search"
          placeholder="Search title or number"
          defaultValue={values.q}
          onChange={(e) => set({ q: e.target.value })}
          aria-label="Search requisitions"
        />
        <select className="field w-auto" value={values.status} onChange={(e) => set({ status: e.target.value })}
          aria-label="Filter by status">
          {STATUSES.map((s) => (
            <option key={s} value={s}>{s ? s.replace('_', ' ') : 'Any status'}</option>
          ))}
        </select>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={values.mine === 'true'} onChange={(e) => set({ mine: e.target.checked ? 'true' : null })} />
          Only mine
        </label>
      </div>

      <Sheet>
        {list.error && <div className="p-4"><ErrorNote error={list.error} /></div>}
        {list.isPending ? (
          <Loading />
        ) : list.data?.items.length === 0 ? (
          <Empty title="No requisitions match">
            Try clearing the filters, or <Link className="text-carbon underline" to="/requisitions/new">raise a new one</Link>.
          </Empty>
        ) : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>Number</th>
                  <th>Title</th>
                  <th>Requested by</th>
                  <th>Department</th>
                  <th>Created</th>
                  <th className="num">Total</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {list.data?.items.map((r) => (
                  <tr key={r.id} className="cursor-pointer" onClick={() => navigate(`/requisitions/${r.id}`)}>
                    <td className="whitespace-nowrap">
                      <Link to={`/requisitions/${r.id}`} className="font-medium text-carbon hover:underline">{r.number}</Link>
                    </td>
                    <td className="max-w-xs">{r.title}</td>
                    <td className="whitespace-nowrap">{r.requester.name}</td>
                    <td>{r.department.name}</td>
                    <td className="whitespace-nowrap text-ink-soft">{date(r.created_at)}</td>
                    <td className="num whitespace-nowrap font-medium">{money(r.total_amount, r.currency)}</td>
                    <td><Status value={r.status} /></td>
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
