import type { ReactNode } from 'react'
import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { useAuth } from './auth'
import { Layout } from './components/Layout'
import { Loading } from './components/ui'
import type { Role } from './lib/types'
import { Approvals } from './pages/Approvals'
import { AuditLog } from './pages/AuditLog'
import { InvoiceDetail } from './pages/InvoiceDetail'
import { InvoiceNew } from './pages/InvoiceNew'
import { Invoices } from './pages/Invoices'
import { Login } from './pages/Login'
import { Overview } from './pages/Overview'
import { PurchaseOrderDetail } from './pages/PurchaseOrderDetail'
import { PurchaseOrders } from './pages/PurchaseOrders'
import { RequisitionDetail } from './pages/RequisitionDetail'
import { RequisitionForm } from './pages/RequisitionForm'
import { Requisitions } from './pages/Requisitions'
import { Suppliers } from './pages/Suppliers'

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
        <Route index element={<Overview />} />
        <Route path="requisitions" element={<Requisitions />} />
        <Route path="requisitions/new" element={<RequisitionForm />} />
        <Route path="requisitions/:id" element={<RequisitionDetail />} />
        <Route path="requisitions/:id/edit" element={<RequisitionForm />} />
        <Route path="approvals" element={<Approvals />} />
        <Route path="purchase-orders" element={<PurchaseOrders />} />
        <Route path="purchase-orders/:id" element={<PurchaseOrderDetail />} />
        <Route path="invoices" element={<RequireRole roles={['finance', 'admin']}><Invoices /></RequireRole>} />
        <Route path="invoices/new" element={<RequireRole roles={['finance', 'admin']}><InvoiceNew /></RequireRole>} />
        <Route path="invoices/:id" element={<RequireRole roles={['finance', 'admin']}><InvoiceDetail /></RequireRole>} />
        <Route path="suppliers" element={<Suppliers />} />
        <Route path="audit" element={<RequireRole roles={['finance', 'admin']}><AuditLog /></RequireRole>} />
        <Route path="*" element={<p className="py-16 text-center text-ink-soft">That page does not exist.</p>} />
      </Route>
    </Routes>
  )
}
