import { useSearchParams } from 'react-router-dom'

export function useListParams<K extends string>(keys: K[]) {
  const [params, setParams] = useSearchParams()
  const values = Object.fromEntries(keys.map((k) => [k, params.get(k) ?? ''])) as Record<K, string>
  const page = Number(params.get('page') ?? 1)

  function set(updates: Partial<Record<K | 'page', string | number | null>>) {
    const next = new URLSearchParams(params)
    Object.entries(updates).forEach(([k, v]) => {
      if (v === null || v === '' || v === undefined) next.delete(k)
      else next.set(k, String(v))
    })
    if (!('page' in updates)) next.delete('page')
    setParams(next, { replace: true })
  }

  return { values, page, set }
}
