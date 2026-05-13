import { useEffect, useRef, type ReactNode } from 'react'

export function Dialog({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean
  onClose: () => void
  title: string
  children: ReactNode
}) {
  const ref = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    if (open && !el.open) el.showModal()
    if (!open && el.open) el.close()
  }, [open])

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      className="m-auto w-[min(32rem,calc(100vw-2rem))] rounded-lg border border-rule bg-white p-0 text-ink shadow-2xl backdrop:bg-ink/40"
    >
      <div className="border-b border-rule px-5 py-3">
        <h2 className="font-semibold">{title}</h2>
      </div>
      <div className="p-5">{children}</div>
    </dialog>
  )
}
