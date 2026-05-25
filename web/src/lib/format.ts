const moneyFormatters = new Map<string, Intl.NumberFormat>()

export function money(value: string | number | null | undefined, currency = 'USD') {
  if (value === null || value === undefined || value === '') return '—'
  let fmt = moneyFormatters.get(currency)
  if (!fmt) {
    fmt = new Intl.NumberFormat(undefined, { style: 'currency', currency, currencyDisplay: 'narrowSymbol', minimumFractionDigits: 2 })
    moneyFormatters.set(currency, fmt)
  }
  return fmt.format(Number(value))
}

export function qty(value: string | number | null | undefined) {
  if (value === null || value === undefined) return '—'
  return Number(value).toLocaleString(undefined, { maximumFractionDigits: 3 })
}

export function date(value: string | null | undefined) {
  if (!value) return '—'
  return new Date(value).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
}

export function dateTime(value: string | null | undefined) {
  if (!value) return '—'
  return new Date(value).toLocaleString(undefined, {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function relative(value: string) {
  const diff = (Date.now() - new Date(value).getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)} h ago`
  if (diff < 86400 * 7) return `${Math.floor(diff / 86400)} d ago`
  return date(value)
}

export function humanize(value: string) {
  const s = value.replace(/_/g, ' ')
  return s.charAt(0).toUpperCase() + s.slice(1)
}
