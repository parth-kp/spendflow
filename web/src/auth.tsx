import { useQuery, useQueryClient } from '@tanstack/react-query'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { api, tokenStore } from './lib/api'
import type { Role, User } from './lib/types'

interface AuthState {
  user: User | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => void
  can: (...roles: Role[]) => boolean
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const qc = useQueryClient()
  const [token, setToken] = useState(tokenStore.get())

  const me = useQuery({
    queryKey: ['session', token],
    queryFn: () => api.get<{ user: User }>('/session').then((r) => r.user),
    enabled: !!token,
    staleTime: 5 * 60_000,
    retry: false,
  })

  const signOut = useCallback(() => {
    tokenStore.set(null)
    setToken(null)
    qc.clear()
  }, [qc])

  useEffect(() => {
    const handler = () => signOut()
    window.addEventListener('spendflow:signed-out', handler)
    return () => window.removeEventListener('spendflow:signed-out', handler)
  }, [signOut])

  const signIn = useCallback(
    async (email: string, password: string) => {
      const res = await api.post<{ token: string; user: User }>('/session', { email, password })
      tokenStore.set(res.token)
      qc.setQueryData(['session', res.token], res.user)
      setToken(res.token)
    },
    [qc],
  )

  const value = useMemo<AuthState>(() => {
    const user = token ? (me.data ?? null) : null
    return {
      user,
      loading: !!token && me.isPending,
      signIn,
      signOut,
      can: (...roles) => !!user && roles.includes(user.role),
    }
  }, [token, me.data, me.isPending, signIn, signOut])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}
