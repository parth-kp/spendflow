import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../lib/api'
import { relative } from '../lib/format'
import type { Notification } from '../lib/types'

const SUBJECT_PATHS: Record<string, string> = {
  Requisition: '/requisitions',
  PurchaseOrder: '/purchase-orders',
  Invoice: '/invoices',
}

export function NotificationBell() {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const qc = useQueryClient()
  const navigate = useNavigate()

  const { data } = useQuery({
    queryKey: ['notifications'],
    queryFn: async () => {
      const res = await api.page<Notification>('/notifications', { per_page: 12 })
      const unread = res.items.filter((n) => !n.read_at).length
      return { ...res, unread }
    },
    refetchInterval: 30_000,
  })

  const readAll = useMutation({
    mutationFn: () => api.post('/notifications/read_all'),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notifications'] }),
  })

  const readOne = useMutation({
    mutationFn: (id: number) => api.patch(`/notifications/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['notifications'] }),
  })

  useEffect(() => {
    if (!open) return
    const close = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [open])

  const unread = data?.unread ?? 0

  return (
    <div className="relative" ref={ref}>
      <button
        className="btn-quiet relative"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        aria-label={`Notifications, ${unread} unread`}
      >
        Notifications
        {unread > 0 && <span className="rounded-full bg-reject px-1.5 text-xs font-bold text-white">{unread}</span>}
      </button>
      {open && (
        <div className="absolute right-0 z-40 mt-2 w-[min(24rem,calc(100vw-2rem))] rounded-lg border border-rule bg-white shadow-lg">
          <div className="flex items-center justify-between border-b border-rule px-4 py-2.5">
            <p className="text-sm font-semibold">Notifications</p>
            {unread > 0 && (
              <button className="text-sm text-carbon hover:underline" onClick={() => readAll.mutate()}>
                Mark all read
              </button>
            )}
          </div>
          <ul className="max-h-96 overflow-y-auto">
            {data?.items.length === 0 && <li className="px-4 py-6 text-center text-sm text-ink-soft">Nothing new.</li>}
            {data?.items.map((n) => (
              <li key={n.id}>
                <button
                  className={`block w-full border-b border-rule/60 px-4 py-2.5 text-left text-sm hover:bg-paper ${
                    n.read_at ? 'text-ink-soft' : ''
                  }`}
                  onClick={() => {
                    if (!n.read_at) readOne.mutate(n.id)
                    const base = n.subject && SUBJECT_PATHS[n.subject.type]
                    if (base) navigate(`${base}/${n.subject!.id}`)
                    setOpen(false)
                  }}
                >
                  <span className="flex items-start gap-2">
                    {!n.read_at && <span className="mt-1.5 size-2 shrink-0 rounded-full bg-carbon" aria-hidden />}
                    <span>
                      <span className="block font-medium">{n.title}</span>
                      {n.body && <span className="block text-ink-soft">{n.body}</span>}
                      <span className="block text-xs text-ink-faint">{relative(n.created_at)}</span>
                    </span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}
