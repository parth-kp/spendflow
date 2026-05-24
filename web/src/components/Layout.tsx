import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../auth'
import { api } from '../lib/api'
import type { Role } from '../lib/types'
import { NotificationBell } from './NotificationBell'

interface NavItem {
  to: string
  label: string
  roles?: Role[]
  badge?: number
}

export function Layout() {
  const { user, signOut } = useAuth()
  const [open, setOpen] = useState(false)
  const inbox = useQuery({
    queryKey: ['requisitions', 'inbox', 'count'],
    queryFn: () => api.page('/requisitions/inbox', { per_page: 1 }),
    refetchInterval: 60_000,
  })

  if (!user) return null

  const groups: { heading: string; items: NavItem[] }[] = [
    {
      heading: 'Buy',
      items: [
        { to: '/', label: 'Overview' },
        { to: '/requisitions', label: 'Requisitions' },
        { to: '/approvals', label: 'Approvals', roles: ['manager', 'finance', 'admin'], badge: inbox.data?.total },
        { to: '/purchase-orders', label: 'Purchase orders' },
      ],
    },
    {
      heading: 'Pay',
      items: [
        { to: '/invoices', label: 'Invoices', roles: ['finance', 'admin'] },
        { to: '/suppliers', label: 'Suppliers' },
      ],
    },
    {
      heading: 'Control',
      items: [
        { to: '/audit', label: 'Audit log', roles: ['finance', 'admin'] },
        { to: '/settings/rules', label: 'Approval rules', roles: ['finance', 'admin'] },
        { to: '/settings/people', label: 'People', roles: ['admin'] },
      ],
    },
  ]

  const nav = (
    <nav className="flex flex-col gap-6 text-sm" aria-label="Main">
      {groups.map((g) => {
        const items = g.items.filter((i) => !i.roles || i.roles.includes(user.role))
        if (!items.length) return null
        return (
          <div key={g.heading}>
            <p className="mb-1.5 px-3 text-xs font-semibold text-white/45">{g.heading}</p>
            <ul className="flex flex-col gap-0.5">
              {items.map((item) => (
                <li key={item.to}>
                  <NavLink
                    to={item.to}
                    end={item.to === '/'}
                    onClick={() => setOpen(false)}
                    className={({ isActive }) =>
                      `flex items-center justify-between rounded-md px-3 py-1.5 transition-colors ${
                        isActive ? 'bg-white/12 font-semibold text-white' : 'text-white/75 hover:bg-white/6 hover:text-white'
                      }`
                    }
                  >
                    {item.label}
                    {!!item.badge && (
                      <span className="rounded-full bg-white px-1.5 text-xs font-bold text-ink">{item.badge}</span>
                    )}
                  </NavLink>
                </li>
              ))}
            </ul>
          </div>
        )
      })}
    </nav>
  )

  return (
    <div className="min-h-dvh lg:grid lg:grid-cols-[232px_1fr]">
      <aside
        className={`${open ? 'fixed inset-0 z-30 block' : 'hidden'} bg-ink px-4 py-5 text-white lg:sticky lg:top-0 lg:block lg:h-dvh`}
      >
        <div className="mb-8 flex items-center justify-between px-3">
          <div>
            <p className="text-lg font-extrabold tracking-tight">SpendFlow</p>
            <p className="text-xs text-white/55">{user.company.name}</p>
          </div>
          <button className="text-white/70 lg:hidden" onClick={() => setOpen(false)} aria-label="Close menu">
            ✕
          </button>
        </div>
        {nav}
      </aside>

      <div className="min-w-0">
        <header className="sticky top-0 z-20 flex items-center justify-between gap-3 border-b border-rule bg-paper/90 px-4 py-2.5 backdrop-blur sm:px-8">
          <button className="btn-quiet lg:hidden" onClick={() => setOpen(true)} aria-label="Open menu">
            Menu
          </button>
          <div className="ml-auto flex items-center gap-3">
            <NotificationBell />
            <div className="text-right text-sm leading-tight">
              <p className="font-semibold">{user.name}</p>
              <p className="text-xs text-ink-soft">
                {user.role[0].toUpperCase() + user.role.slice(1)}
                {user.department && user.department.name.toLowerCase() !== user.role ? `, ${user.department.name}` : ''}
              </p>
            </div>
            <button className="btn-quiet" onClick={signOut}>
              Sign out
            </button>
          </div>
        </header>
        <main className="mx-auto max-w-6xl px-4 py-6 sm:px-8 sm:py-8">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
