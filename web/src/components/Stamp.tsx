import { humanize } from '../lib/format'

type Tone = 'ink' | 'carbon' | 'approve' | 'reject' | 'variance' | 'faint'

const TONES: Record<string, Tone> = {
  draft: 'faint',
  pending_approval: 'carbon',
  pending: 'carbon',
  uploaded: 'carbon',
  processing: 'carbon',
  extracted: 'carbon',
  issued: 'carbon',
  partially_received: 'variance',
  approved: 'approve',
  matched: 'approve',
  received: 'approve',
  paid: 'ink',
  ordered: 'ink',
  closed: 'ink',
  rejected: 'reject',
  extraction_failed: 'reject',
  cancelled: 'faint',
  skipped: 'faint',
  exception: 'variance',
  price_variance: 'variance',
  quantity_variance: 'variance',
  unmatched: 'reject',
}

const TONE_CLASSES: Record<Tone, string> = {
  ink: 'text-ink border-ink/70',
  carbon: 'text-carbon border-carbon/60',
  approve: 'text-approve border-approve/70',
  reject: 'text-reject border-reject/70',
  variance: 'text-variance border-variance/70',
  faint: 'text-ink-faint border-ink-faint/60',
}

const LABELS: Record<string, string> = {
  pending_approval: 'Awaiting approval',
  extraction_failed: 'Could not read',
  partially_received: 'Part received',
}

/** Inline status pill for tables. */
export function Status({ value }: { value: string }) {
  const tone = TONES[value] ?? 'ink'
  return (
    <span
      className={`inline-flex items-center rounded-[3px] border px-1.5 py-px text-xs font-semibold whitespace-nowrap ${TONE_CLASSES[tone]}`}
    >
      {LABELS[value] ?? humanize(value)}
    </span>
  )
}

/** Large rubber-stamp mark used once per document header. */
export function Stamp({ value, note }: { value: string; note?: string }) {
  const tone = TONES[value] ?? 'ink'
  return (
    <div
      aria-label={`Status: ${LABELS[value] ?? humanize(value)}`}
      className={`stamp inline-flex -rotate-[4deg] flex-col items-center rounded-md border-[3px] border-double px-4 py-1.5 ${TONE_CLASSES[tone]}`}
    >
      <span className="text-lg leading-tight font-extrabold tracking-wide uppercase">
        {LABELS[value] ?? humanize(value)}
      </span>
      {note && <span className="text-[11px] font-medium opacity-80">{note}</span>}
    </div>
  )
}
