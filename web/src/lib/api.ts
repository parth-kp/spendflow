const TOKEN_KEY = 'spendflow.token'

export class ApiError extends Error {
  status: number
  details?: Record<string, string[]>

  constructor(status: number, message: string, details?: Record<string, string[]>) {
    super(message)
    this.status = status
    this.details = details
  }
}

export const tokenStore = {
  get: () => {
    try {
      return localStorage.getItem(TOKEN_KEY)
    } catch {
      return null
    }
  },
  set: (token: string | null) => {
    try {
      if (token) localStorage.setItem(TOKEN_KEY, token)
      else localStorage.removeItem(TOKEN_KEY)
    } catch {
      /* storage unavailable: session lasts for this tab only */
    }
  },
}

export interface Page<T> {
  items: T[]
  total: number
  page: number
  perPage: number
}

type Query = Record<string, string | number | boolean | undefined | null>

function buildUrl(path: string, query?: Query) {
  const url = new URL(`/api/v1${path}`, window.location.origin)
  Object.entries(query ?? {}).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, String(v))
  })
  return url.toString()
}

async function request(method: string, path: string, opts: { query?: Query; body?: unknown } = {}) {
  const headers: Record<string, string> = { Accept: 'application/json' }
  const token = tokenStore.get()
  if (token) headers.Authorization = `Bearer ${token}`

  let body: BodyInit | undefined
  if (opts.body instanceof FormData) body = opts.body
  else if (opts.body !== undefined) {
    headers['Content-Type'] = 'application/json'
    body = JSON.stringify(opts.body)
  }

  const res = await fetch(buildUrl(path, opts.query), { method, headers, body })

  if (res.status === 401 && token) {
    tokenStore.set(null)
    window.dispatchEvent(new Event('spendflow:signed-out'))
  }
  if (!res.ok) {
    const data = await res.json().catch(() => ({}))
    throw new ApiError(res.status, data.error ?? `Request failed (${res.status})`, data.details)
  }
  return res
}

async function json<T>(res: Response): Promise<T> {
  return res.status === 204 ? (undefined as T) : res.json()
}

export const api = {
  get: async <T>(path: string, query?: Query) => json<T>(await request('GET', path, { query })),
  page: async <T>(path: string, query?: Query): Promise<Page<T>> => {
    const res = await request('GET', path, { query })
    return {
      items: await res.json(),
      total: Number(res.headers.get('X-Total-Count') ?? 0),
      page: Number(res.headers.get('X-Page') ?? 1),
      perPage: Number(res.headers.get('X-Per-Page') ?? 25),
    }
  },
  post: async <T>(path: string, body?: unknown) => json<T>(await request('POST', path, { body })),
  patch: async <T>(path: string, body?: unknown) => json<T>(await request('PATCH', path, { body })),
  delete: async (path: string) => {
    await request('DELETE', path)
  },
  blob: async (path: string) => (await request('GET', path)).blob(),
}
