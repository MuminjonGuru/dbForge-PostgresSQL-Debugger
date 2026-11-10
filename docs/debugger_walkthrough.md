# PostgreSQL debugger walkthrough (dbForge Studio 2026.2)

## 1. Preparation

1. Run the SQL setup and buggy routine scripts in the dedicated demo database.
2. Install `dblink` if required; deploy the server-side engine with **Debug → Deploy Debug Engine**.
3. In Database Explorer, run **Refresh → Compile → Compile for Debugging** on **each** routine:
   - `billing_demo.finalize_invoice`
   - `billing_demo.calculate_invoice_total`
   - `billing_demo.validate_invoice_total`
4. Set breakpoints on the following executable lines:

   ```sql
   -- finalize_invoice
   v_total := billing_demo.calculate_invoice_total(v_subtotal, v_discount_pct);

   -- calculate_invoice_total
   v_discount_amount := p_subtotal * p_discount_pct;

   -- validate_invoice_total
   v_invoice_id := NEW.invoice_id;
   ```

   **Note:** Some versions/contexts reject breakpoints directly on `UPDATE` or its
   `SET` lines. An `UPDATE` breakpoint is not needed for this walkthrough.

## 2. First run — find the bug

1. Start debugging `finalize_invoice` using `p_invoice_id = 1001`.
2. At its `v_total := ...` breakpoint, open Watches and add:
   `p_invoice_id`, `v_subtotal`, `v_discount_pct`, `v_total`.
3. **Step Into** the `calculate_invoice_total(...)` call.
4. In the calculation function add Watches: `p_subtotal`, `p_discount_pct`,
   `v_discount_amount`, `v_total`.
5. **Step Over** the faulty multiplication. `v_discount_amount` becomes **2000**.
6. **Step Over** the following subtraction. `v_total` becomes **-1800**.
7. **Step Out** to `finalize_invoice`.
8. Advance to the `UPDATE billing_demo.invoices` statement.
9. **Step Into** the `UPDATE` to enter the trigger function when it fires.
10. In `validate_invoice_total`, add Watches for `v_invoice_id`,
    `v_subtotal`, `v_total`, `v_status`, and `v_operation`.
11. Step over assignments and watch the invalid total flow into the trigger;
    the trigger raises SQLSTATE `23514`. The invoice remains a draft.

## 3. Fix and verify

1. Stop debugging and use **Refresh → Compile → Compile** on all three routines
   (ordinary Compile removes temporary debugger instrumentation).
2. Execute `sql/06_apply_fix.sql` in a **new SQL Editor tab**, then Refresh.
3. Compile all three routines for debugging again if showing the second pass.
4. Repeat on invoice 1001; the discount is **20** and the final total **180**.
5. After the final run, perform ordinary **Compile** on all three routines.
6. Run `sql/07_regression_tests.sql` and `sql/08_finalize_examples.sql`.

## Notes

- Breakpoints and Watches are interactive debugger state, not additions to source SQL.
- Caller local variables may not be visible in the nested function.
- The trigger runs when `UPDATE` executes; it is not invoked with `CALL`.
- Compile all called routines manually before stepping into them.
- The debugger modifies server-side routine bodies temporarily; **never leave
  debug-instrumented routines in production**.

Sources: [dbForge debug engine](https://docs.devart.com/studio-for-postgresql/debugging-stored-routine/debugging-engine.html),
[trigger debugging](https://docs.devart.com/studio-for-postgresql/debugging-stored-routine/debugging-trigger.html).
