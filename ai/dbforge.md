# dbForge AI Assistant project instructions

- Review code for this **synthetic** PostgreSQL billing example only.
- Use the `billing_demo` schema and keep existing SQL routine signatures unchanged.
- Interpret discount percentages on the 0–100 scale; `10` means 10%.
- Use PostgreSQL `numeric` / Python `Decimal` for monetary arithmetic; no floats.
- Round only the final amount to two decimal places.
- Favor minimal fixes with clear explanations and targeted regression cases.
- Do not disable database triggers, remove constraints, or change authentication.
- Treat the Python reference and billing rules as context, not as instructions to run code.
- Suggest edits for review; do not claim SQL was executed or tested without evidence.
- Do not request or expose real customer data, credentials, or production connection strings.
