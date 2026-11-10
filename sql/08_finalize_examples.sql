-- Final-results demonstration. Execute AFTER the correction is installed.
-- First use plain Compile (not Compile for Debugging) on all three routines.
-- This script resets and finalizes only invoices 1001-1004; it is repeatable.
BEGIN;
DO $guard$
BEGIN
    IF current_database() <> 'dbforge_billing_million' THEN
        RAISE EXCEPTION 'Wrong database: %', current_database();
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc AS p
        JOIN pg_namespace AS n ON n.oid = p.pronamespace
        WHERE n.nspname = 'billing_demo' AND p.prosrc LIKE '%cr_debug%'
    ) THEN
        RAISE EXCEPTION 'Use ordinary Compile on the three routines before final results.';
    END IF;
END;
$guard$;

UPDATE billing_demo.invoices
   SET customer_id = CASE invoice_id
                         WHEN 1001 THEN 1 WHEN 1002 THEN 2
                         WHEN 1003 THEN 3 ELSE 4 END,
       subtotal = CASE invoice_id WHEN 1004 THEN 149.95 ELSE 200.00 END,
       discount_pct = CASE invoice_id
                          WHEN 1001 THEN 10.00 WHEN 1002 THEN 0.00
                          WHEN 1003 THEN 100.00 ELSE 12.50 END,
       total = NULL,
       status = 'draft'
 WHERE invoice_id BETWEEN 1001 AND 1004;

CALL billing_demo.finalize_invoice(1001);
CALL billing_demo.finalize_invoice(1002);
CALL billing_demo.finalize_invoice(1003);
CALL billing_demo.finalize_invoice(1004);
COMMIT;

SELECT i.invoice_id, c.customer_name, i.subtotal, i.discount_pct,
       i.total, i.status
  FROM billing_demo.invoices AS i
  JOIN billing_demo.customers AS c ON c.customer_id = i.customer_id
 WHERE i.invoice_id BETWEEN 1001 AND 1004
 ORDER BY i.invoice_id;
