import { useQuery } from '@tanstack/react-query'
import { api } from '../lib/api'
import { dateTime, humanize } from '../lib/format'
import type { AuditEvent } from '../lib/types'
import { Sheet, SheetTitle } from './ui'

const VERBS: Record<string, string> = {
  created: 'created this',
  created_manually: 'entered this invoice by hand',
  updated: 'edited this',
  edited: 'corrected fields',
  submitted: 'submitted for approval',
  auto_approved: 'auto-approved (no rule matched)',
  step_approved: 'approved',
  approved: 'final approval recorded',
  rejected: 'rejected',
  revised: 'reopened as a draft',
  cancelled: 'cancelled',
  converted_to_po: 'converted into a purchase order',
  issued: 'issued the purchase order',
  goods_received: 'recorded a goods receipt',
  closed: 'closed',
  uploaded: 'uploaded the document',
  extracted: 'read the document',
  extraction_failed: 'could not read the document',
  matched: 'ran the 3-way match',
  reprocess_requested: 'asked to read the document again',
  paid: 'marked as paid',
}

function detail(e: AuditEvent): string | null {
  const m = e.metadata as Record<string, unknown>
  const parts: string[] = []
  if (m.level) parts.push(`level ${m.level}${m.role ? ` (${m.role})` : ''}`)
  if (m.purchase_order) parts.push(String(m.purchase_order))
  if (m.receipt) parts.push(String(m.receipt))
  if (m.status) parts.push(`result: ${m.status}`)
  if (Array.isArray(m.issues) && m.issues.length) parts.push(`issues: ${m.issues.join(', ')}`)
  if (m.source) parts.push(`via ${m.source}`)
  if (m.override) parts.push('override of match exceptions')
  if (m.error) parts.push(String(m.error))
  return parts.length ? parts.join('; ') : null
}

export function History({ type, id }: { type: 'Requisition' | 'PurchaseOrder' | 'Invoice'; id: number }) {
  const { data } = useQuery({
    queryKey: ['audit', type, id],
    queryFn: () => api.get<AuditEvent[]>('/audit_events', { auditable_type: type, auditable_id: id, per_page: 100 }),
  })

  return (
    <Sheet>
      <SheetTitle>History</SheetTitle>
      <ol className="relative px-4 py-3">
        {data?.map((e) => {
          const extra = detail(e)
          const comment = (e.metadata as { comment?: string }).comment
          return (
            <li key={e.id} className="relative border-l border-rule pb-4 pl-4 last:pb-0">
              <span className="absolute top-1.5 -left-[4.5px] size-2 rounded-full bg-ink-faint" aria-hidden />
              <p className="text-sm">
                <span className="font-semibold">{e.actor?.name ?? 'SpendFlow'}</span>{' '}
                {VERBS[e.action] ?? humanize(e.action)}
              </p>
              {extra && <p className="text-xs text-ink-soft">{extra}</p>}
              {comment && <p className="mt-1 border-l-2 border-rule pl-2 text-sm text-ink-soft italic">“{comment}”</p>}
              <p className="text-xs text-ink-faint">{dateTime(e.created_at)}</p>
            </li>
          )
        })}
        {data?.length === 0 && <li className="text-sm text-ink-soft">No activity yet.</li>}
      </ol>
    </Sheet>
  )
}
