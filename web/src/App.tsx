import type { ReactNode } from 'react'
import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { useAuth } from './auth'
import { Layout } from './components/Layout'
import { Loading } from './components/ui'
import type { Role } from './lib/types'
import { Login } from './pages/Login'

function RequireAuth({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth()
  const location = useLocation()
  if (loading) return <Loading />
  if (!user) return <Navigate to="/login" replace state={{ from: location }} />
  return children
}

export function RequireRole({ roles, children }: { roles: Role[]; children: ReactNode }) {
  const { can } = useAuth()
  if (!can(...roles)) {
    return <p className="py-16 text-center text-ink-soft">This page is only available to {roles.join(', ')} users.</p>
  }
  return children
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route index element={<p>Overview</p>} />
        <Route path="*" element={<p className="py-16 text-center text-ink-soft">That page does not exist.</p>} />
      </Route>
    </Routes>
  )
}
