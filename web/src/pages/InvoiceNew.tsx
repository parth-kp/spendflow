import { useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { InvoiceEditor } from '../components/InvoiceEditor'
import { PageHeader, Sheet } from '../components/ui'

export function InvoiceNew() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  return (
    <>
      <PageHeader
        back={{ to: '/invoices', label: 'Invoices' }}
        title="Enter an invoice"
        subtitle="For paper invoices or anything the reader can't handle. It is matched as soon as you save."
      />
      <Sheet className="max-w-3xl p-4">
        <InvoiceEditor
          onCancel={() => navigate('/invoices')}
          onSaved={(inv) => {
            qc.invalidateQueries({ queryKey: ['invoices'] })
            navigate(`/invoices/${inv.id}`)
          }}
        />
      </Sheet>
    </>
  )
}
