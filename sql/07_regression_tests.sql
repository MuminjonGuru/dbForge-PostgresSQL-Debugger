-- Execute only AFTER 06_apply_fix.sql, preferably after removing debug code.
-- These tests run inside a transaction and ROLLBACK their invoice changes.
-- Expected summary: 21 PASS, 0 FAIL (10 valid, 7 invalid, 4 workflow cases).
BEGIN;
DO $guard$
BEGIN
    IF current_database() <> 'dbforge_billing_million' THEN
        RAISE EXCEPTION 'Wrong database: %', current_database();
    END IF;
END;
$guard$;

CREATE TEMP TABLE demo_test_results (
    test_name text NOT NULL,
    result text NOT NULL CHECK (result IN ('PASS', 'FAIL'))
) ON COMMIT DROP;

DO $test$
DECLARE
    r record;
    actual numeric;
    case_no integer := 0;
BEGIN
    -- Ten valid arithmetic cases (PostgreSQL numeric rounds half away from zero).
    FOR r IN
        SELECT * FROM (VALUES
            (200::numeric, 0::numeric, 200.00::numeric),
            (200::numeric, 10::numeric, 180.00::numeric),
            (200::numeric, 100::numeric, 0.00::numeric),
            (149.95::numeric, 12.5::numeric, 131.21::numeric),
            (0::numeric, 10::numeric, 0.00::numeric),
            (19.99::numeric, 15::numeric, 16.99::numeric),
            (0.05::numeric, 10::numeric, 0.05::numeric),
            (1000000::numeric, 0::numeric, 1000000.00::numeric),
            (1000000::numeric, 100::numeric, 0.00::numeric),
            (25::numeric, 12.5::numeric, 21.88::numeric)
        ) AS cases(subtotal, discount_pct, expected)
    LOOP
        case_no := case_no + 1;
        actual := billing_demo.calculate_invoice_total(r.subtotal, r.discount_pct);
        IF actual IS DISTINCT FROM r.expected THEN
            RAISE EXCEPTION 'Arithmetic case % failed: expected %, got %',
                case_no, r.expected, actual;
        END IF;
        INSERT INTO demo_test_results VALUES ('arithmetic ' || case_no, 'PASS');
    END LOOP;

    -- Seven invalid-input cases must raise SQLSTATE 22023.
    case_no := 0;
    FOR r IN
        SELECT * FROM (VALUES
            (NULL::numeric, 10::numeric),
            (200::numeric, NULL::numeric),
            (-1::numeric, 10::numeric),
            (200::numeric, -1::numeric),
            (200::numeric, 101::numeric),
            (1000001::numeric, 10::numeric),
            ('NaN'::numeric, 10::numeric)
        ) AS cases(subtotal, discount_pct)
    LOOP
        case_no := case_no + 1;
        BEGIN
            PERFORM billing_demo.calculate_invoice_total(r.subtotal, r.discount_pct);
            RAISE EXCEPTION 'Invalid case % was incorrectly accepted', case_no;
        EXCEPTION WHEN SQLSTATE '22023' THEN
            INSERT INTO demo_test_results VALUES ('invalid input ' || case_no, 'PASS');
        END;
    END LOOP;
END;
$test$;

-- Restore the four demo invoices temporarily, finalize, and verify values.
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

DO $check$
DECLARE
    r record;
    actual numeric;
    actual_status text;
BEGIN
    FOR r IN
        SELECT * FROM (VALUES
            (1001, 180.00::numeric),
            (1002, 200.00::numeric),
            (1003, 0.00::numeric),
            (1004, 131.21::numeric)
        ) AS expected(invoice_id, expected_total)
    LOOP
        SELECT i.total, i.status INTO actual, actual_status
          FROM billing_demo.invoices AS i
         WHERE i.invoice_id = r.invoice_id;
        IF actual IS DISTINCT FROM r.expected_total
           OR actual_status IS DISTINCT FROM 'finalized' THEN
            RAISE EXCEPTION 'Workflow test for invoice % failed: total %, status %',
                r.invoice_id, actual, actual_status;
        END IF;
        INSERT INTO demo_test_results VALUES ('invoice ' || r.invoice_id, 'PASS');
    END LOOP;
END;
$check$;

SELECT count(*) FILTER (WHERE result = 'PASS') AS passed,
       count(*) FILTER (WHERE result = 'FAIL') AS failed
  FROM demo_test_results;

SELECT test_name, result
  FROM demo_test_results
 ORDER BY test_name;

-- Discard test updates: the 1,000,000-row dataset remains in its prior state.
ROLLBACK;
