# AI Assistant review prompt

Open `reference/billing_reference.py`, `ai/billing_rules.md`, and the corrected SQL
`sql/06_apply_fix.sql` as documents in dbForge Studio. Attach the first two and
provide the SQL file as current-document context (or attach it too).

Copy this prompt into dbForge AI Assistant:

> Review my PostgreSQL `billing_demo.calculate_invoice_total` function against the
> attached billing business rules and Python Decimal reference. Verify the 0–100
> discount percentage scale, input validation, numeric precision, rounding, and
> edge cases including 0% and 100% discounts. Identify any remaining risks, and
> propose minimal SQL improvements and regression tests. Do not change routine
> signatures, weaken constraints, or assume any tests have been executed.

AI-generated output requires independent review and testing; do not execute it
blindly against a database.
