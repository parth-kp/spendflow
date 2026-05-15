import { money, qty } from '../lib/format'
import type { InvoiceDetail, MatchLine, PoLine } from '../lib/types'
import { Status } from './Stamp'

/**
 * The 3-way match, one row per invoice line: what was ordered (PO),
 * what arrived (goods receipts), and what the supplier billed.
 */
export function MatchGrid({ invoice, poLines }: { invoice: InvoiceDetail; poLines: PoLine[] }) {
  const lines = invoice.match_result.lines ?? []
  const currency = invoice.currency ?? 'USD'
  if (!lines.length) return <p className="px-4 py-6 text-sm text-ink-soft">No match has run yet.</p>

  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[640px] border-collapse text-sm">
        <thead>
          <tr className="text-left text-xs text-ink-soft">
            <th className="px-4 pt-3 pb-1 font-semibold">Item</th>
            <th className="border-l border-rule bg-paper/60 px-3 pt-3 pb-1 font-semibold">Ordered</th>
            <th className="border-l border-rule bg-paper/60 px-3 pt-3 pb-1 font-semibold">Received</th>
            <th className="border-l border-rule px-3 pt-3 pb-1 font-semibold">Billed</th>
            <th className="px-3 pt-3 pb-1"><span className="sr-only">Result</span></th>
          </tr>
        </thead>
        <tbody>
          {lines.map((m) => (
            <Row key={m.invoice_line_id} m={m} po={poLines.find((p) => p.id === m.purchase_order_line_id)} currency={currency} />
          ))}
        </tbody>
      </table>
    </div>
  )
}

function Row({ m, po, currency }: { m: MatchLine; po?: PoLine; currency: string }) {
  const priceOff = m.status === 'price_variance' || (m.notes ?? []).some((n) => n.startsWith('Unit price'))
  const qtyOff = (m.notes ?? []).some((n) => n.startsWith('Billed'))
  const off = 'bg-variance-tint text-variance font-semibold'

  return (
    <>
      <tr className="border-t border-rule align-top">
        <td className="px-4 py-3">
          <p className="font-medium">{m.description}</p>
          {po && <p className="text-xs text-ink-faint">PO line {m.po_line_no}: {po.description}</p>}
        </td>
        <td className="border-l border-rule bg-paper/60 px-3 py-3 tabular-nums">
          {po ? (
            <>
              <p>{qty(po.quantity)} {po.unit}</p>
              <p className="text-ink-soft">at {money(m.po_unit_price, currency)}</p>
            </>
          ) : (
            <p className="text-ink-faint">Not on PO</p>
          )}
        </td>
        <td className="border-l border-rule bg-paper/60 px-3 py-3 tabular-nums">
          {po ? (
            <>
              <p>{qty(m.received_quantity)}</p>
              {Number(m.previously_invoiced) > 0 && <p className="text-xs text-ink-soft">{qty(m.previously_invoiced)} already billed</p>}
            </>
          ) : (
            <p className="text-ink-faint">—</p>
          )}
        </td>
        <td className="border-l border-rule px-3 py-3 tabular-nums">
          <p className={qtyOff ? `${off} -mx-1 rounded px-1` : ''}>{qty(m.quantity)}</p>
          <p className={priceOff ? `${off} -mx-1 rounded px-1` : 'text-ink-soft'}>at {money(m.unit_price, currency)}</p>
        </td>
        <td className="px-3 py-3 text-right"><Status value={m.status} /></td>
      </tr>
      {m.notes?.length > 0 && (
        <tr>
          <td colSpan={5} className="px-4 pb-3 text-xs text-variance">{m.notes.join('. ')}</td>
        </tr>
      )}
    </>
  )
}
