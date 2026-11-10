-- Reset only invoices 1001-1004. Keeps the other 999,996 invoices untouched.
-- Does not change the installed calculation function (buggy or corrected).
BEGIN;
DO $guard$
BEGIN
    IF current_database() <> 'dbforge_billing_million' THEN
        RAISE EXCEPTION 'Wrong database: %', current_database();
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

DO $check$
BEGIN
    IF (SELECT count(*) FROM billing_demo.invoices
        WHERE invoice_id BETWEEN 1001 AND 1004 AND status = 'draft'
          AND total IS NULL) <> 4 THEN
        RAISE EXCEPTION 'Expected all four reserved demo invoices to be drafts.';
    END IF;
END;
$check$;
COMMIT;
