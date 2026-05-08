import { useState, type FormEvent } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../auth'
import { ErrorNote } from '../components/ui'

const DEMO_ACCOUNTS = [
  { email: 'eli@acme-corp.test', who: 'Eli, engineer: raises requisitions' },
  { email: 'maya@acme-corp.test', who: 'Maya, engineering manager: first approver' },
  { email: 'fiona@acme-corp.test', who: 'Fiona, finance: POs, invoices, matching' },
  { email: 'admin@acme-corp.test', who: 'Avery, admin: rules and people' },
]

export function Login() {
  const { user, signIn } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<unknown>(null)
  const [busy, setBusy] = useState(false)

  if (user) return <Navigate to="/" replace />

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await signIn(email, password)
    } catch (err) {
      setError(err)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid min-h-dvh lg:grid-cols-[1fr_1.1fr]">
      <div className="flex items-center justify-center px-6 py-12">
        <form onSubmit={submit} className="w-full max-w-sm space-y-4">
          <div>
            <p className="text-2xl font-extrabold tracking-tight">SpendFlow</p>
            <p className="mt-1 text-ink-soft">Sign in to raise, approve and pay for what your team buys.</p>
          </div>
          <ErrorNote error={error} />
          <label className="block">
            <span className="label">Work email</span>
            <input className="field" type="email" autoComplete="username" required value={email}
              onChange={(e) => setEmail(e.target.value)} />
          </label>
          <label className="block">
            <span className="label">Password</span>
            <input className="field" type="password" autoComplete="current-password" required value={password}
              onChange={(e) => setPassword(e.target.value)} />
          </label>
          <button className="btn-primary w-full" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign in'}
          </button>

          <div className="rounded-lg border border-dashed border-rule p-3 text-sm">
            <p className="mb-2 font-medium">Demo accounts (password <code>password123</code>)</p>
            <ul className="space-y-1">
              {DEMO_ACCOUNTS.map((a) => (
                <li key={a.email}>
                  <button type="button" className="text-left text-carbon hover:underline"
                    onClick={() => { setEmail(a.email); setPassword('password123') }}>
                    {a.who}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </form>
      </div>

      <div className="relative hidden overflow-hidden bg-ink lg:block" aria-hidden>
        <div className="absolute inset-0 flex items-center justify-center p-16">
          <div className="w-full max-w-md rotate-[1.5deg] rounded-sm bg-white p-8 text-ink shadow-2xl">
            <div className="flex items-start justify-between border-b-2 border-ink pb-3">
              <div>
                <p className="text-xl font-extrabold">Purchase order</p>
                <p className="text-sm text-ink-soft">PO-00042 to Northwind Traders</p>
              </div>
              <div className="stamp -rotate-[8deg] rounded-md border-[3px] border-double border-approve/80 px-3 py-1 text-approve">
                <p className="text-base font-extrabold tracking-wide uppercase">Matched</p>
              </div>
            </div>
            <table className="mt-4 w-full text-sm">
              <tbody>
                {[
                  ['A4 copy paper box', '10', '$300.00'],
                  ['Laser toner cartridge', '4', '$360.00'],
                  ['Desk organiser', '12', '$144.00'],
                ].map(([d, q, a]) => (
                  <tr key={d} className="border-b border-rule">
                    <td className="py-2">{d}</td>
                    <td className="py-2 text-right tabular-nums text-ink-soft">{q}</td>
                    <td className="py-2 text-right tabular-nums">{a}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="mt-4 text-right text-lg font-bold tabular-nums">$804.00</p>
            <div className="mt-6 grid grid-cols-3 gap-2 text-center text-xs text-ink-soft">
              <p className="rounded border border-rule py-1.5">Ordered 22</p>
              <p className="rounded border border-rule py-1.5">Received 22</p>
              <p className="rounded border border-rule py-1.5">Billed 22</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
