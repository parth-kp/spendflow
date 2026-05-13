import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Empty, ErrorNote, Loading, PageHeader, Pagination, Sheet } from '../components/ui'
import { api } from '../lib/api'
import { money, relative } from '../lib/format'
import type { Requisition } from '../lib/types'

export function Approvals() {
  const [page, setPage] = useState(1)
  const inbox = useQuery({
    queryKey: ['requisitions', 'inbox', { page }],
    queryFn: () => api.page<Requisition>('/requisitions/inbox', { page }),
    placeholderData: keepPreviousData,
  })

  return (
    <>
      <PageHeader
        title="Approvals"
        subtitle="Requisitions where you are the next approver. The oldest request is at the top."
      />
      <Sheet>
        {inbox.error && <div className="p-4"><ErrorNote error={inbox.error} /></div>}
        {inbox.isPending ? (
          <Loading />
        ) : inbox.data?.items.length === 0 ? (
          <Empty title="You're all caught up">New requests that need your sign-off will show up here.</Empty>
        ) : (
          <ul>
            {inbox.data?.items.map((r) => (
              <li key={r.id} className="border-b border-rule/70 last:border-0">
                <Link to={`/requisitions/${r.id}`} className="grid gap-1 px-4 py-3 hover:bg-paper/70 sm:grid-cols-[1fr_auto] sm:items-center">
                  <div className="min-w-0">
                    <p className="truncate font-semibold">{r.title}</p>
                    <p className="text-sm text-ink-soft">
                      {r.number} from {r.requester.name}, {r.department.name}
                      {r.supplier ? `, ${r.supplier.name}` : ''}
                    </p>
                  </div>
                  <div className="flex items-center gap-4 sm:justify-end">
                    <span className="text-xs text-ink-faint">waiting {r.submitted_at ? relative(r.submitted_at).replace(' ago', '') : ''}</span>
                    <span className="text-lg font-bold tabular-nums">{money(r.total_amount, r.currency)}</span>
                    <span className="btn-quiet">Review</span>
                  </div>
                </Link>
              </li>
            ))}
          </ul>
        )}
        {inbox.data && <Pagination {...inbox.data} onPage={setPage} />}
      </Sheet>
    </>
  )
}
