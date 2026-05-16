import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Dialog } from '../components/Dialog'
import { ErrorNote, Field, Loading, PageHeader, Sheet, SheetTitle } from '../components/ui'
import { api } from '../lib/api'
import type { Department, Role, User } from '../lib/types'

const ROLES: Role[] = ['employee', 'manager', 'finance', 'admin']

export function People() {
  const qc = useQueryClient()
  const [editing, setEditing] = useState<Partial<User> & { password?: string; active?: boolean } | null>(null)
  const [deptName, setDeptName] = useState('')
  const [deptCode, setDeptCode] = useState('')
  const users = useQuery({ queryKey: ['users', 'all'], queryFn: () => api.get<(User & { active?: boolean })[]>('/users', { include_inactive: true }) })
  const departments = useQuery({ queryKey: ['departments'], queryFn: () => api.get<Department[]>('/departments') })

  const addDept = useMutation({
    mutationFn: () => api.post('/departments', { department: { name: deptName, code: deptCode } }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['departments'] }); setDeptName(''); setDeptCode('') },
  })

  return (
    <>
      <PageHeader
        title="People"
        subtitle="Roles decide what each person can do: employees raise requests, managers approve their department, finance issues POs and pays invoices."
        actions={<button className="btn-primary" onClick={() => setEditing({ role: 'employee' })}>Add person</button>}
      />
      <div className="grid gap-6 lg:grid-cols-[1fr_300px]">
        <Sheet>
          {users.isPending ? <Loading /> : (
            <div className="overflow-x-auto">
              <table className="table">
                <thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Department</th><th /></tr></thead>
                <tbody>
                  {users.data?.map((u) => (
                    <tr key={u.id}>
                      <td className="font-medium">{u.name}</td>
                      <td className="text-ink-soft">{u.email}</td>
                      <td className="capitalize">{u.role}</td>
                      <td>{u.department?.name ?? '—'}</td>
                      <td className="text-right"><button className="text-sm text-carbon hover:underline" onClick={() => setEditing(u)}>Edit</button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Sheet>
        <Sheet className="self-start">
          <SheetTitle>Departments</SheetTitle>
          <ul className="divide-y divide-rule/70 text-sm">
            {departments.data?.map((d) => (
              <li key={d.id} className="flex justify-between px-4 py-2">
                <span>{d.name} <span className="text-ink-faint">{d.code}</span></span>
                <span className="text-ink-soft">{d.user_count}</span>
              </li>
            ))}
          </ul>
          <form className="space-y-2 border-t border-rule p-4" onSubmit={(e) => { e.preventDefault(); addDept.mutate() }}>
            <ErrorNote error={addDept.error} />
            <input className="field" placeholder="Department name" required value={deptName} onChange={(e) => setDeptName(e.target.value)} aria-label="Department name" />
            <div className="flex gap-2">
              <input className="field" placeholder="Code" required value={deptCode} onChange={(e) => setDeptCode(e.target.value)} aria-label="Department code" />
              <button className="btn-quiet shrink-0" disabled={addDept.isPending}>Add</button>
            </div>
          </form>
        </Sheet>
      </div>
      {editing && <PersonDialog person={editing} departments={departments.data ?? []} onClose={() => setEditing(null)} />}
    </>
  )
}

function PersonDialog({ person, departments, onClose }: { person: Partial<User> & { active?: boolean }; departments: Department[]; onClose: () => void }) {
  const qc = useQueryClient()
  const [name, setName] = useState(person.name ?? '')
  const [email, setEmail] = useState(person.email ?? '')
  const [role, setRole] = useState<Role>(person.role ?? 'employee')
  const [deptId, setDeptId] = useState(person.department ? String(person.department.id) : '')
  const [password, setPassword] = useState('')
  const save = useMutation({
    mutationFn: () => {
      const body = { user: { name, email, role, department_id: deptId || null, ...(password ? { password } : {}) } }
      return person.id ? api.patch(`/users/${person.id}`, body) : api.post('/users', body)
    },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['users'] }); qc.invalidateQueries({ queryKey: ['departments'] }); onClose() },
  })
  const deactivate = useMutation({
    mutationFn: () => api.patch(`/users/${person.id}`, { user: { active: false } }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['users'] }); onClose() },
  })

  return (
    <Dialog open onClose={onClose} title={person.id ? `Edit ${person.name}` : 'Add a person'}>
      <form className="space-y-3" onSubmit={(e: FormEvent) => { e.preventDefault(); save.mutate() }}>
        <ErrorNote error={save.error ?? deactivate.error} />
        <Field label="Name"><input className="field" required value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <Field label="Email"><input className="field" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Role">
            <select className="field capitalize" value={role} onChange={(e) => setRole(e.target.value as Role)}>
              {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
            </select>
          </Field>
          <Field label="Department">
            <select className="field" value={deptId} onChange={(e) => setDeptId(e.target.value)}>
              <option value="">None</option>
              {departments.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
            </select>
          </Field>
        </div>
        <Field label={person.id ? 'New password (leave blank to keep)' : 'Password'} hint="At least 8 characters.">
          <input className="field" type="password" minLength={8} required={!person.id} value={password} onChange={(e) => setPassword(e.target.value)} />
        </Field>
        <div className="flex items-center justify-between gap-2 pt-2">
          {person.id && person.active !== false ? (
            <button type="button" className="text-sm text-reject hover:underline" onClick={() => deactivate.mutate()}>Deactivate</button>
          ) : <span />}
          <div className="flex gap-2">
            <button type="button" className="btn-quiet" onClick={onClose}>Back</button>
            <button className="btn-primary" disabled={save.isPending}>Save</button>
          </div>
        </div>
      </form>
    </Dialog>
  )
}
