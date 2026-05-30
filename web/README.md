# SpendFlow client

React 19 + TypeScript, built with Vite. See the [root README](../README.md) for setup.

- `src/lib/api.ts`: fetch wrapper (JWT, pagination headers, typed errors)
- `src/pages/`: one file per screen
- `src/components/MatchGrid.tsx`: the PO / receipt / invoice comparison
- `src/components/Stamp.tsx`: document status stamps

`npm run dev` proxies `/api` to `http://localhost:3000` (override with `API_URL`).
