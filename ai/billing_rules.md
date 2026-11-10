# Billing rules — synthetic PostgreSQL demo

This document describes an educational invoice workflow. All people, companies, and invoice rows are fictional.

## Calculation contract

- `discount_pct` uses a **0–100 percentage scale**. For example, `10` means 10%, not 0.10.
- Subtotal must be non-null, finite, and between 0 and 1,000,000 inclusive.
- Discount must be non-null, finite, and between 0 and 100 inclusive.
- Correct discount amount: `subtotal * discount_pct / 100`.
- Correct total: `round(subtotal - discount_amount, 2)`.
- Round **only the final total**, using PostgreSQL `numeric` and Python `Decimal`.
- A 100% discount is valid, and the final total of zero is valid.
- Finalized invoices require a non-null total between zero and subtotal.
- Draft invoices have no stored total (`NULL`).
- Rejected finalization must not modify the original draft.
- A previously finalized invoice cannot be finalized again without explicitly resetting a demo fixture.

## Reserved test invoices

| Invoice | Customer | Subtotal | Discount | Expected total |
|---|---|---:|---:|---:|
| 1001 | Northstar Labs | 200.00 | 10% | **180.00** |
| 1002 | Cedar Studio | 200.00 | 0% | **200.00** |
| 1003 | Orbit Learning | 200.00 | 100% | **0.00** |
| 1004 | Harbor Apps | 149.95 | 12.5% | **131.21** |

## Database integration

- The procedure is `billing_demo.finalize_invoice(integer)`.
- The calculation function is `billing_demo.calculate_invoice_total(numeric,numeric)`.
- The trigger function is `billing_demo.validate_invoice_total()`.
- The row-level trigger `invoice_total_guard` validates an insert or update before it commits.
- Keep parameter names, SQL routine signatures, and 0–100 percentage semantics stable.
- Do not disable the trigger or weaken constraints to conceal a bug.
