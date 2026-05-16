import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { useAuth } from '../auth'
import { Dialog } from '../components/Dialog'
import { ErrorNote, Field, Loading, PageHeader, Sheet, SheetTitle } from '../components/ui'
import { api } from '../lib/api'
import { money } from '../lib/format'
import type { ApprovalRule, Department, User } from '../lib/types'

const ROLE = { manager: 'Department manager', finance: 'Finance', admin: 'Admin', employee: 'Employee' }

export function ApprovalRules() {
  const { can, user } = useAuth()
  const admin = can('admin')
  const currency = user!.company.currency
  const [editing, setEditing] = useState<Partial<ApprovalRule> | null>(null)
  const [amount, setAmount] = useState('7500')
  const [deptId, setDeptId] = useState('')
  const qc = useQueryClient()

  const rules = useQuery({ queryKey: ['approval_rules'], queryFn: () => api.get<ApprovalRule[]>('/approval_rules') })
  const departments = useQuery({ queryKey: ['departments'], queryFn: () => api.get<Department[]>('/departments') })
  const preview = useQuery({
    queryKey: ['approval_rules', 'preview', amount, deptId],
    queryFn: () => api.get<ApprovalRule[]>('/approval_rules/preview', { amount, department_id: deptId }),
    enabled: Number(amount) >= 0,
  })
  const remove = useMutation({
    mutationFn: (id: number) => api.delete(`/approval_rules/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['approval_rules'] }),
  })

  const levels = [...new Set(rules.data?.map((r) => r.level))].sort()

  return (
    <>
      <PageHeader
        title="Approval rules"
        subtitle="Each level applies once a requisition reaches its minimum amount. A department rule replaces the company-wide rule at the same level."
        actions={admin && <button className="btn-primary" onClick={() => setEditing({ level: 1, min_amount: '0', approver_role: 'manager' })}>Add rule</button>}
      />
      <div className="grid gap-6 lg:grid-cols-[1fr_300px]">
        <Sheet>
          {rules.isPending ? <Loading /> : (
            <div className="divide-y divide-rule">
              {levels.map((level) => (
                <div key={level}>
                  <p className="bg-paper/60 px-4 py-2 text-xs font-semibold text-ink-soft">Level {level}</p>
                  <table className="table">
                    <tbody>
                      {rules.data?.filter((r) => r.level === level).map((r) => (
                        <tr key={r.id}>
                          <td className="font-medium">{r.name}</td>
                          <td>from {money(r.min_amount, currency)}</td>
                          <td>{r.approver ? r.approver.name : ROLE[r.approver_role]}</td>
                          <td className="text-ink-soft">{r.department ? `${r.department.name} only` : 'All departments'}</td>
                          {admin && (
                            <td className="text-right whitespace-nowrap">
                              <button className="text-sm text-carbon hover:underline" onClick={() => setEditing(r)}>Edit</button>{' '}
                              <button className="ml-2 text-sm text-reject hover:underline" onClick={() => confirm(`Delete "${r.name}"?`) && remove.mutate(r.id)}>Delete</button>
                            </td>
                          )}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ))}
            </div>
          )}
        </Sheet>

        <Sheet className="self-start">
          <SheetTitle>Try an amount</SheetTitle>
          <div className="space-y-3 p-4">
            <Field label="Amount">
              <input className="field" type="number" min="0" value={amount} onChange={(e) => setAmount(e.target.value)} />
            </Field>
            <Field label="Department">
              <select className="field" value={deptId} onChange={(e) => setDeptId(e.target.value)}>
                <option value="">Any</option>
                {departments.data?.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
              </select>
            </Field>
            <div className="text-sm">
              {preview.data?.length === 0 ? (
                <p className="text-ink-soft">Approved automatically.</p>
              ) : (
                <ol className="list-decimal space-y-0.5 pl-5">
                  {preview.data?.map((r) => <li key={r.id}>{r.name}</li>)}
                </ol>
              )}
            </div>
          </div>
        </Sheet>
      </div>
      {editing && <RuleDialog rule={editing} departments={departments.data ?? []} onClose={() => setEditing(null)} />}
    </>
  )
}

function RuleDialog({ rule, departments, onClose }: { rule: Partial<ApprovalRule>; departments: Department[]; onClose: () => void }) {
  const qc = useQueryClient()
  const [name, setName] = useState(rule.name ?? '')
  const [level, setLevel] = useState(String(rule.level ?? 1))
  const [minAmount, setMinAmount] = useState(rule.min_amount ?? '0')
  const [role, setRole] = useState(rule.approver_role ?? 'manager')
  const [deptId, setDeptId] = useState(rule.department ? String(rule.department.id) : '')
  const [approverId, setApproverId] = useState(rule.approver ? String(rule.approver.id) : '')
  const approvers = useQuery({ queryKey: ['users', 'approvers'], queryFn: () => api.get<User[]>('/users') })

  const save = useMutation({
    mutationFn: () => {
      const body = { approval_rule: { name, level, min_amount: minAmount, approver_role: role, department_id: deptId || null, approver_id: approverId || null } }
      return rule.id ? api.patch(`/approval_rules/${rule.id}`, body) : api.post('/approval_rules', body)
    },
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['approval_rules'] }); onClose() },
  })

  return (
    <Dialog open onClose={onClose} title={rule.id ? 'Edit approval rule' : 'Add approval rule'}>
      <form className="space-y-3" onSubmit={(e: FormEvent) => { e.preventDefault(); save.mutate() }}>
        <ErrorNote error={save.error} />
        <Field label="Name"><input className="field" required value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Level"><input className="field" type="number" min="1" max="10" value={level} onChange={(e) => setLevel(e.target.value)} /></Field>
          <Field label="Applies from amount"><input className="field" type="number" min="0" value={minAmount} onChange={(e) => setMinAmount(e.target.value)} /></Field>
        </div>
        <Field label="Who approves">
          <select className="field" value={role} onChange={(e) => setRole(e.target.value as ApprovalRule['approver_role'])}>
            <option value="manager">Manager of the requester's department</option>
            <option value="finance">Anyone in finance</option>
            <option value="admin">An admin</option>
          </select>
        </Field>
        <Field label="Specific person (optional)" hint="Overrides the role. Must be a manager, finance or admin user.">
          <select className="field" value={approverId} onChange={(e) => setApproverId(e.target.value)}>
            <option value="">Anyone with that role</option>
            {approvers.data?.filter((u) => u.role !== 'employee').map((u) => <option key={u.id} value={u.id}>{u.name} ({u.role})</option>)}
          </select>
        </Field>
        <Field label="Department">
          <select className="field" value={deptId} onChange={(e) => setDeptId(e.target.value)}>
            <option value="">All departments</option>
            {departments.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
          </select>
        </Field>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" className="btn-quiet" onClick={onClose}>Back</button>
          <button className="btn-primary" disabled={save.isPending}>Save rule</button>
        </div>
      </form>
    </Dialog>
  )
}
