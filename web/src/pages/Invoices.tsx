import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useRef, useState, type DragEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Status } from '../components/Stamp'
import { Empty, ErrorNote, Loading, PageHeader, Pagination, Sheet } from '../components/ui'
import { api } from '../lib/api'
import { date, money } from '../lib/format'
import type { Invoice, InvoiceDetail } from '../lib/types'
import { useListParams } from '../lib/useListParams'

const FILTERS: [string, string][] = [
  ['', 'All'],
  ['exception', 'Needs review'],
  ['matched', 'Matched'],
  ['uploaded,processing,extracted', 'Reading'],
  ['extraction_failed', 'Could not read'],
  ['approved', 'Ready to pay'],
  ['paid', 'Paid'],
  ['rejected', 'Rejected'],
]

const ACCEPT = '.pdf,.png,.jpg,.jpeg,.webp,.txt'

export function Invoices() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const { values, page, set } = useListParams(['status'])
  const query = { ...values, page }
  const fileInput = useRef<HTMLInputElement>(null)
  const [dragging, setDragging] = useState(false)

  const list = useQuery({
    queryKey: ['invoices', query],
    queryFn: () => api.page<Invoice>('/invoices', query),
    placeholderData: keepPreviousData,
    refetchInterval: (q) =>
      q.state.data?.items.some((i) => i.status === 'uploaded' || i.status === 'processing') ? 3000 : false,
  })

  const upload = useMutation({
    mutationFn: (file: File) => {
      const form = new FormData()
      form.append('document', file)
      return api.post<InvoiceDetail>('/invoices', form)
    },
    onSuccess: (inv) => {
      qc.invalidateQueries({ queryKey: ['invoices'] })
      navigate(`/invoices/${inv.id}`)
    },
  })

  function onDrop(e: DragEvent) {
    e.preventDefault()
    setDragging(false)
    const file = e.dataTransfer.files[0]
    if (file) upload.mutate(file)
  }

  return (
    <>
      <PageHeader
        title="Invoices"
        subtitle="Upload a supplier invoice. SpendFlow reads it, finds the purchase order, and checks it against what was ordered and received."
        actions={<Link to="/invoices/new" className="btn-quiet">Enter manually</Link>}
      />

      <div
        onDragOver={(e) => { e.preventDefault(); setDragging(true) }}
        onDragLeave={() => setDragging(false)}
        onDrop={onDrop}
        className={`mb-6 flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed px-6 py-8 text-center transition-colors ${
          dragging ? 'border-carbon bg-carbon-tint' : 'border-rule bg-white'
        }`}
      >
        <p className="font-semibold">Drop an invoice here</p>
        <p className="text-sm text-ink-soft">PDF, photo or scan, up to 10 MB</p>
        <button className="btn-primary mt-2" disabled={upload.isPending} onClick={() => fileInput.current?.click()}>
          {upload.isPending ? 'Uploading…' : 'Choose file'}
        </button>
        <input ref={fileInput} type="file" accept={ACCEPT} className="hidden"
          onChange={(e) => e.target.files?.[0] && upload.mutate(e.target.files[0])} />
        {upload.error && <ErrorNote error={upload.error} />}
      </div>

      <div className="mb-3 flex flex-wrap gap-1" role="tablist" aria-label="Filter invoices">
        {FILTERS.map(([value, label]) => (
          <button key={label} role="tab" aria-selected={values.status === value}
            className={`rounded-md px-3 py-1.5 text-sm ${values.status === value ? 'bg-ink font-semibold text-white' : 'text-ink-soft hover:bg-white'}`}
            onClick={() => set({ status: value })}>
            {label}
          </button>
        ))}
      </div>

      <Sheet>
        {list.error && <div className="p-4"><ErrorNote error={list.error} /></div>}
        {list.isPending ? (
          <Loading />
        ) : list.data?.items.length === 0 ? (
          <Empty title="No invoices here">Upload one above to see the match.</Empty>
        ) : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr><th>Invoice</th><th>Supplier</th><th>PO</th><th>Invoice date</th><th>Due</th><th className="num">Total</th><th>Status</th></tr>
              </thead>
              <tbody>
                {list.data?.items.map((inv) => (
                  <tr key={inv.id} className="cursor-pointer" onClick={() => navigate(`/invoices/${inv.id}`)}>
                    <td>
                      <Link to={`/invoices/${inv.id}`} className="font-medium text-carbon hover:underline">
                        {inv.invoice_number ?? `Upload #${inv.id}`}
                      </Link>
                    </td>
                    <td>{inv.supplier?.name ?? <span className="text-ink-faint">Unknown</span>}</td>
                    <td>{inv.purchase_order?.number ?? <span className="text-ink-faint">Not linked</span>}</td>
                    <td className="whitespace-nowrap">{date(inv.invoice_date)}</td>
                    <td className="whitespace-nowrap">{date(inv.due_date)}</td>
                    <td className="num font-medium">{money(inv.total_amount, inv.currency ?? 'USD')}</td>
                    <td><Status value={inv.status} /></td>
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
