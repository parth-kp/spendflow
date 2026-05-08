import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ApiError } from '../lib/api'

export function PageHeader({
  title,
  subtitle,
  actions,
  back,
}: {
  title: ReactNode
  subtitle?: ReactNode
  actions?: ReactNode
  back?: { to: string; label: string }
}) {
  return (
    <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {back && (
          <Link to={back.to} className="mb-1 inline-block text-sm text-ink-soft hover:text-carbon">
            ‹ {back.label}
          </Link>
        )}
        <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-ink-soft">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </header>
  )
}

export function Sheet({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <section className={`rounded-lg border border-rule bg-sheet ${className}`}>{children}</section>
}

export function SheetTitle({ children, aside }: { children: ReactNode; aside?: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-rule px-4 py-3">
      <h2 className="text-sm font-semibold">{children}</h2>
      {aside}
    </div>
  )
}

export function Empty({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="px-6 py-12 text-center">
      <p className="font-semibold">{title}</p>
      {children && <div className="mt-1 text-sm text-ink-soft">{children}</div>}
    </div>
  )
}

export function Loading() {
  return <p className="px-4 py-10 text-center text-sm text-ink-faint">Loading…</p>
}

export function ErrorNote({ error }: { error: unknown }) {
  if (!error) return null
  const message = error instanceof Error ? error.message : 'Something went wrong'
  const details = error instanceof ApiError ? error.details : undefined
  return (
    <div role="alert" className="rounded-md border border-reject/30 bg-reject-tint px-3 py-2 text-sm text-reject">
      <p className="font-medium">{message}</p>
      {details && (
        <ul className="mt-1 list-disc pl-5">
          {Object.entries(details).map(([field, msgs]) =>
            msgs.map((m) => <li key={field + m}>{m}</li>),
          )}
        </ul>
      )}
    </div>
  )
}

export function Pagination({
  page,
  perPage,
  total,
  onPage,
}: {
  page: number
  perPage: number
  total: number
  onPage: (p: number) => void
}) {
  const pages = Math.max(1, Math.ceil(total / perPage))
  if (total <= perPage) return null
  return (
    <nav className="flex items-center justify-between px-4 py-3 text-sm text-ink-soft" aria-label="Pagination">
      <span>
        {(page - 1) * perPage + 1}–{Math.min(page * perPage, total)} of {total.toLocaleString()}
      </span>
      <div className="flex gap-2">
        <button className="btn-quiet" disabled={page <= 1} onClick={() => onPage(page - 1)}>
          Previous
        </button>
        <button className="btn-quiet" disabled={page >= pages} onClick={() => onPage(page + 1)}>
          Next
        </button>
      </div>
    </nav>
  )
}

export function Field({ label, children, hint }: { label: string; children: ReactNode; hint?: string }) {
  return (
    <label className="block">
      <span className="label">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-xs text-ink-faint">{hint}</span>}
    </label>
  )
}
