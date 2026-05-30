# SpendFlow

SpendFlow is a small multi-tenant procure-to-pay app. An employee asks to buy something. The request goes through approvals that depend on its amount and department, and then becomes a purchase order. Deliveries are recorded against the order. Finally, the supplier's invoice is checked against both the order and what actually arrived before anyone pays it.

You can upload an invoice as a PDF or a photo. An LLM reads it, SpendFlow finds the purchase order it belongs to, and a 3-way match flags price and quantity differences line by line.

**Stack:** Rails 8.1 API, PostgreSQL 16, Sidekiq/Redis, React 19 + TypeScript (Vite, TanStack Query, Tailwind), RSpec, Docker.

## The flow

```
Employee            Manager / Finance          Finance                 Receiver              Accounts payable
────────            ─────────────────          ───────                 ────────              ────────────────
Requisition  ──▶    Approval chain     ──▶     Purchase order  ──▶     Goods receipt  ──▶    Invoice
(draft)             level 1, 2, 3 …            (issued)                (partial / full)      upload → LLM extract
                    by amount + dept                                                         → find PO → 3-way match
                                                                                             → approve → pay
```

Every step writes an append-only audit event: who did it, when, from which request, and with what comment.

## Features

| Area | What it does | Where |
|---|---|---|
| Multi-tenancy | `acts_as_tenant` row-level scoping on every model. The tenant comes from the JWT on each request and is passed explicitly into Sidekiq jobs. A `validates_same_tenant` guard stops a record from pointing at another company's data. Request specs run with tenant enforcement on. | `app/models/concerns/tenant_guard.rb`, `spec/requests/tenant_isolation_spec.rb` |
| Roles & permissions | Pundit policies and scopes for employee, manager, finance and admin. Deny by default; `verify_authorized` / `verify_policy_scoped` run on every action. | `app/policies/` |
| Approval workflow | AASM state machines for requisitions, POs and invoices. Approval rules are per level, have an amount threshold, and can be overridden per department. Steps are sequential. Requesters can never approve their own requests, and rejections need a reason. | `app/services/approvals/workflow.rb`, `app/models/approval_rule.rb` |
| Purchase orders & receiving | Approved requisitions become POs. Deliveries can be partial, and over-receipt is blocked. | `app/services/procurement/` |
| 3-way match | Invoice price vs PO price, within the company's tolerance. Invoice quantity vs received-but-not-yet-invoiced quantity. Supplier and currency checks, and duplicate-invoice detection. | `app/services/matching/three_way_match.rb` |
| LLM invoice reading | OpenRouter with a strict JSON schema. Text-layer PDFs go to `gpt-4o-mini` (~3s). Scans and photos go to `gemini-2.5-flash`, because gpt-4o-mini returned empty fields for images in testing. Output is validated and normalized before anything is saved. With no API key, an offline heuristic extractor is used. | `app/services/extraction/` |
| Background jobs | Sidekiq handles invoice processing, matching and notifications (in-app plus email). If processing fails, the invoice is marked failed instead of being left stuck. | `app/jobs/` |
| Controls | Duplicate invoices can never be approved. The person who uploads an invoice can't approve it. Approving an invoice with match exceptions requires a written reason. | `app/services/invoices/approve.rb` |
| Audit trail | `AuditEvent` rows are read-only once written and can't be destroyed. They are shown as a timeline on each document and as a filterable company-wide log. | `app/models/audit_event.rb` |
| Performance | 3M-row benchmark, composite, partial and trigram indexes, and an inbox query rewrite. The before/after timings are measured, not estimated. | [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md) |

## Run it

### Docker (everything)

```bash
OPENROUTER_API_KEY=sk-or-... docker compose up --build
open http://localhost:8080
```

The API container prepares the database and loads demo data the first time it starts. Without `OPENROUTER_API_KEY`, invoices are read by the offline heuristic extractor, which handles the text samples in `docs/sample-invoices/`.

### Local development

Requirements: Ruby 3.4, Node 24, PostgreSQL 16, Redis.

```bash
# API on :3000
cd api
bundle install
cp .env.example .env.development.local   # add OPENROUTER_API_KEY
bin/rails db:prepare                      # creates, migrates and seeds
bin/rails server

# Background jobs
cd api && bundle exec sidekiq -C config/sidekiq.yml

# Client on :5173 (proxies /api to :3000)
cd web
npm install
npm run dev
```

### Demo accounts

Every account's password is `password123`.

| Email | Role | Try |
|---|---|---|
| `eli@acme-corp.test` | Employee, Engineering | Raise a requisition and watch the approval chain preview update |
| `maya@acme-corp.test` | Manager, Engineering | Approve or reject from the inbox |
| `fiona@acme-corp.test` | Finance | Issue POs, upload `docs/sample-invoices/*.pdf`, review matches |
| `frank@acme-corp.test` | Finance | Approve invoices Fiona uploaded (segregation of duties) |
| `admin@acme-corp.test` | Admin | Edit approval rules and people |
| `admin@globex-industries.test` | Admin of a second tenant | Confirm you can't see Acme's data |

Suggested walkthrough:

1. As Fiona, upload `contoso-CH-90211.pdf`. It quotes PO-00003, but bills 6 monitors at $395 when only 3 arrived and the PO price was $380. Both problems show up in the match grid.
2. Upload `northwind-NW-1042.pdf`. It is a clean match.
3. Upload the `-scan.png` of the same invoice. It goes through the vision model and comes back flagged as a duplicate.

## Tests

```bash
cd api && bundle exec rspec
```

There are 132 examples. They cover:
- models and state machines
- the approval workflow, including sequential levels, eligibility, and self-approval
- the 3-way match and duplicate detection
- extraction, with OpenRouter stubbed through WebMock
- Sidekiq jobs
- Pundit scoping
- request specs for every endpoint, including cross-tenant access attempts

An `ApprovalInboxQuery` spec checks the denormalized SQL inbox against the Ruby eligibility rule for every role.

## Performance

See [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md). Measured on 400k requisitions and 1.6M audit events, the approval inbox went from 28ms to 0.04ms, the company audit log from 47ms to 0.02ms, and the finance queues from 11ms to 0.06ms. To reproduce:

```bash
createdb spendflow_perf
cd api
DATABASE_NAME=spendflow_perf bin/rails db:schema:load perf:seed perf:benchmark LABEL=mine
```

## Deploying

`render.yaml` is a Render Blueprint for Postgres, Redis, the API, the Sidekiq worker and the nginx-served client. Set `OPENROUTER_API_KEY`, `CORS_ORIGINS`, and `API_UPSTREAM` (the API service's URL) in the dashboard.

## Layout

```
api/                Rails API
  app/controllers/api/v1/   JSON endpoints
  app/policies/             Pundit
  app/services/             approvals, procurement, extraction, matching, invoices
  app/queries/              approval inbox, dashboard
  app/jobs/                 Sidekiq jobs
  lib/perf/                 dataset generator and EXPLAIN ANALYZE benchmark
web/                React client
docs/               performance write-up, benchmark output, sample invoices
```
