# Query performance: before and after

All timings come from `EXPLAIN (ANALYZE, BUFFERS)` on the app's real query objects (policy scopes, `ApprovalInboxQuery`, `DashboardQuery`, `PurchaseOrderFinder`). Each figure is the median of 7 warm runs, including planning time. The raw output, with SQL and plans, is in [`docs/perf/`](perf/).

## Setup

- PostgreSQL 16.15 (Postgres.app), Apple Silicon laptop, default config.
- `bin/rails perf:seed` loads a skewed multi-tenant dataset into a separate `spendflow_perf` database. It has 10 companies, and one of them owns ~60% of the rows, much as a big customer would on shared infrastructure:

| table | rows |
|---|---|
| requisitions | 400,000 |
| requisition_lines | 800,000 |
| approval_steps | 646,602 |
| purchase_orders | 150,000 |
| invoices | 120,000 |
| notifications | 400,000 |
| audit_events | 1,600,000 |

- Queries run as users of the largest tenant.

```bash
createdb spendflow_perf
DATABASE_NAME=spendflow_perf bin/rails db:schema:load perf:seed
DATABASE_NAME=spendflow_perf bin/rails perf:benchmark LABEL=baseline
```

## Results (ms, median)

The **baseline** schema already has Rails' single-column foreign-key indexes (`company_id`, `requester_id`, …), so this is not a strawman with no indexes. **Indexed** adds the migration `AddQueryIndexes`. **Tuned** adds the `current_approver_*` denormalization and the inbox query rewrite.

| query | baseline | indexed | tuned | speed-up |
|---|---:|---:|---:|---:|
| requisitions: my list | 0.17 | 0.03 | 0.03 | 6× |
| requisitions: my list count | 0.14 | 0.15 | 0.15 | – |
| requisitions: manager list | 5.57 | 5.97 | 6.13 | – |
| requisitions: pending (finance) | 10.86 | 0.04 | 0.06 | 181× |
| requisitions: search title | 48.65 | 8.22 | 8.44 | 6× |
| approval inbox: manager | 28.26 | 15.86 | 0.04 | 706× |
| approval inbox: finance | 12.46 | 0.30 | 0.05 | 249× |
| approval inbox: finance count | 47.81 | 23.09 | 1.17 | 41× |
| audit trail: one record | 0.02 | 0.02 | 0.02 | – |
| audit log: company page | 46.97 | 0.02 | 0.02 | 2348× |
| notifications: unread count | 0.14 | 0.01 | 0.01 | 14× |
| notifications: list | 0.15 | 0.16 | 0.15 | – |
| invoices: exceptions | 7.76 | 0.03 | 0.03 | 259× |
| invoices: exceptions count | 7.32 | 0.61 | 0.59 | 12× |
| dashboard: spend by department | 17.79 | 2.88 | 2.81 | 6× |
| po finder: supplier candidates | 0.25 | 0.21 | 0.21 | – |

## What changed and why

### 1. Composite indexes that match `WHERE … ORDER BY … LIMIT`

The finance queues filter one tenant by status and show the newest first. With only `company_id` indexed, Postgres read every row of the large tenant and sorted it to return 25 rows. An index on `(company_id, status, created_at DESC)` returns them already in order, so the scan stops after 25 rows. The same pattern covers invoices and the company-wide audit log (`(company_id, created_at DESC, id DESC)`). The audit log fell from 47ms to 0.02ms because Postgres no longer sorts 1M audit rows.

### 2. Partial indexes for small hot slices

Only about 12% of requisitions are `pending_approval`, and only a fraction of approval steps are `pending`. Partial indexes such as `WHERE status = 'pending'` stay small and are the only part the inbox ever reads. The same idea applies to unread notifications (`WHERE read_at IS NULL`) and to approved spend for the dashboard. The dashboard index also `INCLUDE`s `department_id, total_amount`, so the aggregate becomes an index-only scan.

### 3. Trigram index for `ILIKE '%term%'`

A B-tree cannot serve a leading wildcard. `pg_trgm` GIN indexes on `title` and `number` turn the search from a sequential scan into a bitmap index scan. It still takes ~8ms, because a common word like "batch" matches many rows and the matches must be sorted. That is acceptable for an interactive search box.

### 4. Changing the query shape, not just the indexes (approval inbox)

Indexes alone took the manager inbox only from 28ms to 16ms. The cause was the query itself: to find a requisition's *current* step, it ran a correlated `NOT EXISTS (lower pending level)` check against every pending requisition in the tenant. No index removes that per-row work.

The fix is to store the current approver on the requisition:

- `current_approver_role`
- `current_approver_id`

`Approvals::Workflow` updates both columns inside the same row lock that changes the steps. The inbox then becomes a plain filter on `requisitions`, served by `idx_requisitions_inbox (company_id, current_approver_role, department_id, submitted_at) WHERE status = 'pending_approval'`. The manager inbox dropped from 28ms to 0.04ms, and the finance count from 48ms to 1.2ms.

Denormalizing creates two copies of the same fact, which can drift apart. The spec `ApprovalInboxQuery agrees with ApprovalStep#actionable_by?` checks the SQL path against the Ruby rule for every role, so drift fails CI. The migration backfills existing rows with a single `DISTINCT ON` update.

## Things I measured and left alone

- **Manager list (~6ms).** The scope is `requester_id = me OR department_id = my_dept`, newest first. The `OR` means Postgres combines two bitmap scans and then sorts, so neither ordered index can satisfy the `LIMIT`. A `UNION ALL` of two ordered, limited subqueries would bring it under 1ms, but it would complicate the Pundit scope for a query that is already fast. I'd revisit it if managers' departments grow by 10×.
- **Counts for pagination headers.** `X-Total-Count` costs one extra query per list. On the hot paths it is now an index-only count (0.6–1.2ms). On larger tables I'd switch to keyset pagination with "has more".

## Gotcha I hit: the backfill made the dashboard slower

After the `current_approver_*` backfill, the dashboard query briefly went from 2.9ms back to **24ms**. The `UPDATE` left ~46k dead tuples and cleared the visibility-map bits on those pages. The planner then priced the index-only scan as too expensive and picked a different plan. A `VACUUM ANALYZE requisitions` restored 2.8ms. In production, autovacuum would catch up on its own. For large backfills, I'd run `VACUUM (ANALYZE)` as part of the deploy step rather than wait for it.

## Also in the code

- The list endpoints use `includes` for every association they serialize, so a page costs a fixed number of queries.
- `NumberSequence.next_for` uses a single `INSERT … ON CONFLICT DO UPDATE … RETURNING`. Document numbers are therefore unique and gap-free per tenant, with no read-then-write race. The trade-off is that concurrent creators for one tenant queue on a single row lock until their transaction commits.
- All indexes are created `CONCURRENTLY` (`disable_ddl_transaction!`), so the migration does not block writes on a live database.
