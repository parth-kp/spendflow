import { useQuery } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { api } from '../lib/api'

export function DocumentPreview({ invoiceId, contentType }: { invoiceId: number; contentType: string }) {
  const blob = useQuery({
    queryKey: ['invoice-document', invoiceId],
    queryFn: () => api.blob(`/invoices/${invoiceId}/document`),
    staleTime: Infinity,
  })
  const [url, setUrl] = useState<string | null>(null)
  const [text, setText] = useState<string | null>(null)

  useEffect(() => {
    if (!blob.data) return
    if (contentType === 'text/plain') {
      blob.data.text().then(setText)
      return
    }
    const u = URL.createObjectURL(blob.data)
    setUrl(u)
    return () => URL.revokeObjectURL(u)
  }, [blob.data, contentType])

  if (blob.isPending) return <p className="p-4 text-sm text-ink-faint">Loading document…</p>
  if (text !== null) return <pre className="max-h-[32rem] overflow-auto p-4 text-xs leading-relaxed whitespace-pre-wrap">{text}</pre>
  if (!url) return null
  if (contentType.startsWith('image/')) return <img src={url} alt="Uploaded invoice" className="w-full" />
  return <iframe src={url} title="Uploaded invoice" className="h-[32rem] w-full" />
}
