import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { useAuth } from '../auth'
import { Status } from '../components/Stamp'
import { ErrorNote, Loading, PageHeader, Sheet, SheetTitle } from '../components/ui'
import { api } from '../lib/api'
import { money } from '../lib/format'
import type { Dashboard, Requisition } from '../lib/types'

export function Overview() {
  const { user } = useAuth()
  const currency = user!.company.currency
  const dash = useQuery({ queryKey: ['dashboard'], queryFn: () => api.get<Dashboard>('/dashboard') })
  const inbox = useQuery({
    queryKey: ['requisitions', 'inbox', { per_page: 5 }],
    queryFn: () => api.page<Requisition>('/requisitions/inbox', { per_page: 5 }),
    enabled: user!.role !== 'employee',
  })
  const mine = useQuery({
    queryKey: ['requisitions', { mine: true, per_page: 5 }],
    queryFn: () => api.page<Requisition>('/requisitions', { mine: true, per_page: 5 }),
  })

  if (dash.isPending) return <Loading />
  if (dash.error) return <ErrorNote error={dash.error} />
  const d = dash.data
  const finance = d.spend_by_department !== undefined
  const spend = Object.entries(d.spend_by_department ?? {}).sort((a, b) => Number(b[1]) - Number(a[1]))
  const maxSpend = Math.max(1, ...spend.map(([, v]) => Number(v)))
  const exceptions = d.invoices_by_status?.exception ?? 0

  return (
    <>
      <PageHeader
        title={`Good to see you, ${user!.name.split(' ')[0]}`}
        subtitle={
          d.awaiting_my_approval > 0
            ? `${d.awaiting_my_approval} requisition${d.awaiting_my_approval === 1 ? ' is' : 's are'} waiting on your decision.`
            : 'Nothing is waiting on you right now.'
        }
        actions={
          <Link to="/requisitions/new" className="btn-primary">
            New requisition
          </Link>
        }
      />

      {finance && (
        <dl className="mb-6 grid grid-cols-2 gap-px overflow-hidden rounded-lg border border-rule bg-rule md:grid-cols-4">
          {[
            { label: 'Open purchase orders', value: money(d.open_po_value, currency) },
            { label: 'Approved payables due in 7 days', value: money(d.payables_due_7d, currency) },
            {
              label: 'Invoices with match exceptions',
              value: exceptions,
              to: '/invoices?status=exception',
              alert: exceptions > 0,
            },
            {
              label: 'Average time to approve (90 days)',
              value: d.avg_approval_hours == null ? '—' : `${d.avg_approval_hours} h`,
            },
          ].map((s) => (
            <div key={s.label} className="bg-white px-4 py-3">
              <dt className="text-xs text-ink-soft">{s.label}</dt>
              <dd className={`mt-0.5 text-xl font-bold tabular-nums ${s.alert ? 'text-variance' : ''}`}>
                {s.to ? <Link to={s.to} className="hover:underline">{s.value}</Link> : s.value}
              </dd>
            </div>
          ))}
        </dl>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        {user!.role !== 'employee' && (
          <Sheet>
            <SheetTitle aside={<Link to="/approvals" className="text-sm text-carbon hover:underline">Open inbox</Link>}>
              Waiting for your approval
            </SheetTitle>
            <RequisitionList items={inbox.data?.items} empty="Your approval inbox is clear." />
          </Sheet>
        )}

        <Sheet>
          <SheetTitle aside={<Link to="/requisitions?mine=true" className="text-sm text-carbon hover:underline">All of mine</Link>}>
            Your recent requisitions
          </SheetTitle>
          <RequisitionList items={mine.data?.items} empty="You haven't raised anything yet." />
        </Sheet>

        {finance && spend.length > 0 && (
          <Sheet>
            <SheetTitle>Approved spend by department, last 90 days</SheetTitle>
            <ul className="space-y-3 p-4">
              {spend.map(([dept, total]) => (
                <li key={dept}>
                  <div className="mb-1 flex justify-between text-sm">
                    <span>{dept}</span>
                    <span className="tabular-nums">{money(total, currency)}</span>
                  </div>
                  <div className="h-2 rounded-full bg-paper">
                    <div className="h-2 rounded-full bg-carbon" style={{ width: `${(Number(total) / maxSpend) * 100}%` }} />
                  </div>
                </li>
              ))}
            </ul>
          </Sheet>
        )}

        {finance && !!d.top_suppliers?.length && (
          <Sheet>
            <SheetTitle>Top suppliers by PO value, last 90 days</SheetTitle>
            <table className="table">
              <tbody>
                {d.top_suppliers.map((s) => (
                  <tr key={s.name}>
                    <td>{s.name}</td>
                    <td className="num">{money(s.total, currency)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Sheet>
        )}
      </div>
    </>
  )
}

function RequisitionList({ items, empty }: { items?: Requisition[]; empty: string }) {
  if (!items) return <Loading />
  if (!items.length) return <p className="px-4 py-8 text-center text-sm text-ink-soft">{empty}</p>
  return (
    <ul>
      {items.map((r) => (
        <li key={r.id} className="border-b border-rule/70 last:border-0">
          <Link to={`/requisitions/${r.id}`} className="flex items-center justify-between gap-3 px-4 py-2.5 hover:bg-paper/70">
            <span className="min-w-0">
              <span className="block truncate font-medium">{r.title}</span>
              <span className="text-xs text-ink-soft">
                {r.number}, {r.requester.name}
              </span>
            </span>
            <span className="flex shrink-0 flex-col items-end gap-1">
              <span className="text-sm font-semibold tabular-nums">{money(r.total_amount, r.currency)}</span>
              <Status value={r.status} />
            </span>
          </Link>
        </li>
      ))}
    </ul>
  )
}
