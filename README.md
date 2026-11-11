# Debug PostgreSQL stored procedures and triggers with 1 MILLION invoices

**dbForge Studio for PostgreSQL 2026.2 · PostgreSQL Debugger · AI Assistant**

An end-to-end, reproducible billing demo accompanying my sponsored YouTube walkthrough of [dbForge Studio for PostgreSQL](https://www.devart.com/dbforge/postgresql/studio/). The repository contains **SQL scripts, a one-million-invoice dataset generator, the intentionally broken calculation, its fix, regression checks, and AI Assistant context files**.

> **Watch the video:**

[![Watch on YouTube](https://img.youtube.com/vi/h7OsMC9pWk8/maxresdefault.jpg)](https://www.youtube.com/watch?v=h7OsMC9pWk8)

## What are we debugging?

An invoice has a **$200.00 subtotal and a 10% discount**. It should cost **$180.00**. Instead, a PL/pgSQL function accidentally multiplies the subtotal by `10` rather than `10 / 100`, calculating a **$2,000 discount** and a **−$1,800 total**.

A `BEFORE UPDATE` trigger detects the invalid total and rejects the transaction. The debugger lets us follow the call chain, inspect variables, correct the calculation, and rerun the tests.

```sql
-- ❌ Deliberately incorrect:
v_discount_amount := p_subtotal * p_discount_pct;

-- ✅ Corrected:
v_discount_amount := p_subtotal * p_discount_pct / 100.0;
```

### Expected invoice results

| Invoice | Customer | Subtotal | Discount | Correct total |
|---|---|---:|---:|---:|
| `1001` | Northstar Labs | $200.00 | 10% | **$180.00** |
| `1002` | Cedar Studio | $200.00 | 0% | **$200.00** |
| `1003` | Orbit Learning | $200.00 | 100% | **$0.00** |
| `1004` | Harbor Apps | $149.95 | 12.5% | **$131.21** |

## Repository contents

```text
.
├── README.md
├── .gitignore
├── sql/
│   ├── 00_create_database.sql
│   ├── 00_preflight.sql
│   ├── 00_enable_dblink.sql
│   ├── 01_schema_and_seed.sql
│   ├── 02_install_buggy_routines.sql
│   ├── 03_reset_demo_invoices.sql
│   ├── 04_reproduce_bug.sql
│   ├── 05_inspect_data.sql
│   ├── 06_apply_fix.sql
│   ├── 07_regression_tests.sql
│   └── 08_finalize_examples.sql
├── reference/
│   └── billing_reference.py
├── tests/
│   └── test_billing_reference.py
├── ai/
│   ├── billing_rules.md
│   ├── dbforge.md
│   └── review_prompt.md
└── docs/
    ├── debugger_walkthrough.md
    └── schema.md
```

## Prerequisites

- **PostgreSQL 11+** with sufficient free storage for one million invoices.
- **dbForge Studio for PostgreSQL 2026.2** for the visual debugger and AI Assistant portions. The SQL scripts also run with a standard PostgreSQL client.
- A disposable local or test PostgreSQL server. **Never run the setup against production.**
- Permission to create the demo database, schema, and routines. Deploying the debugger requires the permissions described in [Devart's debugger documentation](https://docs.devart.com/studio-for-postgresql/debugging-stored-routine/debugging-engine.html).
- The PostgreSQL `dblink` extension for dbForge's debug engine (see below).
- Optional: Python **3.10+** to run the independent Decimal reference and its tests. No Python dependencies are needed.

## Quick start

**1. Create the database.** In dbForge Studio, create a database called `dbforge_billing_million` and connect to it. Alternatively, run [`sql/00_create_database.sql`](sql/00_create_database.sql) on an administrative connection outside a transaction, then reconnect to the new database.

**2. Generate the data.** Run [`sql/01_schema_and_seed.sql`](sql/01_schema_and_seed.sql). It creates the `billing_demo` schema with **50,000 customers and 1,000,000 invoices**. It is a **destructive rebuild of the demo schema**, guarded by the exact database name. The seed is generated using `generate_series`, so you don't need to download a huge CSV file.

After seeding, expect:

| Table/Status | Count |
|---|---:|
| Customers | `50,000` |
| Invoices | `1,000,000` |
| Draft invoices | `200,004` |
| Finalized invoices | `799,996` |

**3. Install the bug.** Run [`sql/02_install_buggy_routines.sql`](sql/02_install_buggy_routines.sql) to create:

- `billing_demo.calculate_invoice_total(numeric, numeric)` — intentionally faulty discount calculation.
- `billing_demo.finalize_invoice(integer)` — procedure that calculates and finalizes an invoice.
- `billing_demo.validate_invoice_total()` — trigger function that rejects invalid totals.
- `invoice_total_guard` — a row-level `BEFORE INSERT OR UPDATE` trigger on invoices.

**4. Reproduce the failure.** Run [`sql/04_reproduce_bug.sql`](sql/04_reproduce_bug.sql) **on its own in autocommit mode**. The exception is expected:

```text
Invoice 1001 has invalid total: -1800.00
SQLSTATE: 23514
```

Then run [`sql/05_inspect_data.sql`](sql/05_inspect_data.sql). Invoice `1001` should still be a draft with `NULL` total because the failed statement is rolled back.

**5. Debug the flow.** Read [`docs/debugger_walkthrough.md`](docs/debugger_walkthrough.md) for the precise breakpoints, Watches, and Step Into / Step Over sequence. You can inspect the bug before applying the fix.

**6. Apply the fix.** Stop debugging and use **ordinary Compile** on all three routines to remove debugging instrumentation. Then run [`sql/06_apply_fix.sql`](sql/06_apply_fix.sql) independently. Refresh and compile the routines for debugging again if you want to record a second pass.

**7. Test and finalize.** After removing debugging instrumentation again, run [`sql/07_regression_tests.sql`](sql/07_regression_tests.sql). The expected result is **21 PASS, 0 FAIL**; the workflow tests roll back their changes. Then run [`sql/08_finalize_examples.sql`](sql/08_finalize_examples.sql) to commit the four correct totals and show the final result grid.

### SQL execution order (summary)

| File | Run when | Purpose |
|---|---|---|
| `00_create_database.sql` | Once, admin connection | Create the disposable database |
| `00_preflight.sql` | Optional, connected to demo DB | Read-only environment checks |
| `00_enable_dblink.sql` | If extension is missing | Install debugger prerequisite; elevated permissions may be required |
| `01_schema_and_seed.sql` | First | **Rebuilds** schema and generates all rows |
| `02_install_buggy_routines.sql` | After seed | Add intentionally incorrect calculation and the workflow |
| `03_reset_demo_invoices.sql` | Between takes | Reset only invoices 1001–1004 |
| `04_reproduce_bug.sql` | Before applying fix | Expected exception |
| `05_inspect_data.sql` | Anytime after seeding | Inspect counts and reserved invoices |
| `06_apply_fix.sql` | After debugging | Replace faulty calculator |
| `07_regression_tests.sql` | After fix | 21 checks; temporary changes rolled back |
| `08_finalize_examples.sql` | Final step | Commit correct results for all four reserved invoices |

## Configure the dbForge debugger

The **debugger engine is deployed to the same demo database** as the routines. If `dblink` is not installed, run [`sql/00_enable_dblink.sql`](sql/00_enable_dblink.sql) as a sufficiently privileged user, then select **Debug → Deploy Debug Engine** in dbForge Studio.

In Database Explorer, **Refresh**, then choose **Compile → Compile for Debugging** on each of the three routines. Start `finalize_invoice` with parameter `p_invoice_id = 1001`.

The primary breakpoints are on the `v_total := ...` call in the procedure, the incorrect `v_discount_amount := ...` assignment in the calculation function, and the first scalar assignment in the trigger function. Use **Step Into** to enter the calculation, **Step Over** to observe incorrect intermediate values, **Step Out**, and **Step Into** the procedure's `UPDATE` to reach the trigger. The trigger rejects `-1800.00` before the invoice can be finalized.

**Note:** dbForge may refuse a breakpoint directly on the `UPDATE` or `SET` lines. That's fine: use the breakpoint on the preceding `v_total` assignment and step to the `UPDATE` instead.

**After each debugging session**, use **Compile → Compile** (without debugging) on all three routines. This strips inserted debug-engine statements; do not leave them active on production servers. See [Devart's debug engine guide](https://docs.devart.com/studio-for-postgresql/debugging-stored-routine/debugging-engine.html).

## Review the corrected function with dbForge AI Assistant

Open the following files as documents in dbForge Studio and supply them as chat context:

1. [`reference/billing_reference.py`](reference/billing_reference.py) — independent Python `Decimal` implementation.
2. [`ai/billing_rules.md`](ai/billing_rules.md) — requirements and edge cases.
3. [`sql/06_apply_fix.sql`](sql/06_apply_fix.sql) — corrected SQL function, either as the active document with current-document context enabled or explicitly attached.

Use the example in [`ai/review_prompt.md`](ai/review_prompt.md). [`ai/dbforge.md`](ai/dbforge.md) contains optional reusable project instructions.

AI Assistant uses snapshots of **open, saved** documents, so review your selected context before submitting it. Its suggestions still require independent testing. See [document attachment documentation](https://docs.devart.com/ai-assistant/attach-documents-to-chat.html).

## Run the Python reference tests

```bash
python reference/billing_reference.py
python -m unittest discover -s tests -v
```

The Python checks use only the standard library. They **do not** connect to PostgreSQL or validate the dbForge graphical debugger.

## Repeating the demonstration

For another attempt at the faulty flow:

1. Stop any debugging session and remove debug instrumentation with ordinary Compile.
2. Run `sql/03_reset_demo_invoices.sql`.
3. Run `sql/02_install_buggy_routines.sql` to reinstall the bug.
4. Recompile each of the three routines for debugging, then start `finalize_invoice(1001)`.

For another corrected run, apply `sql/06_apply_fix.sql` again, clean up instrumentation, and run `sql/07_regression_tests.sql` / `sql/08_finalize_examples.sql`.

## Safety and limitations

- **Do not run on production.** `sql/01_schema_and_seed.sql` explicitly drops and recreates the `billing_demo` schema in the dedicated demo database.
- The data is fully synthetic; no actual billing, payment processing, or credentials are involved.
- The 1-million-row dataset is **generated**, not committed. Storage and execution time vary by machine and server.
- This demo illustrates business-logic debugging and validation. It is not a benchmark of database performance and should not be represented as one.
- The SQL and dbForge GUI workflows should be tested on your own PostgreSQL installation before publication. The included Python unit tests check only the mathematical reference, not the SQL execution.

## Official documentation

- [dbForge Studio for PostgreSQL](https://www.devart.com/dbforge/postgresql/studio/)
- [dbForge 2026.2 overview](https://www.devart.com/blog/whats-new-in-dbforge-2026-2-2.html)
- [Set up the PostgreSQL debugger engine](https://docs.devart.com/studio-for-postgresql/debugging-stored-routine/debugging-engine.html)
- [Debug a PostgreSQL trigger function](https://docs.devart.com/studio-for-postgresql/debugging-stored-routine/debugging-trigger.html)
- [Attach documents in dbForge AI Assistant](https://docs.devart.com/ai-assistant/attach-documents-to-chat.html)

