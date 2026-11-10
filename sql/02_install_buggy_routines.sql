-- INTENTIONALLY BUGGY teaching fixture; never run in a production database.
-- Stop debugging and remove existing debug instrumentation before reinstalling.
BEGIN;
DO $guard$
BEGIN
    IF current_database() <> 'dbforge_billing_million' THEN
        RAISE EXCEPTION 'Wrong database: %', current_database();
    END IF;
END;
$guard$;

CREATE OR REPLACE FUNCTION billing_demo.calculate_invoice_total(
    p_subtotal numeric,
    p_discount_pct numeric
)
RETURNS numeric
LANGUAGE plpgsql
AS $function$
DECLARE
    v_discount_amount numeric;
    v_total numeric;
BEGIN
    IF p_subtotal IS NULL OR p_subtotal < 0 OR p_subtotal > 1000000 THEN
        RAISE EXCEPTION 'Subtotal must be between 0 and 1000000.'
            USING ERRCODE = '22023';
    END IF;

    IF p_discount_pct IS NULL OR p_discount_pct < 0 OR p_discount_pct > 100 THEN
        RAISE EXCEPTION 'Discount must be between 0 and 100 percent.'
            USING ERRCODE = '22023';
    END IF;

    -- BUG: 10 (ten percent) is treated as a multiplier of ten, not 10/100.
    v_discount_amount := p_subtotal * p_discount_pct;
    v_total := round(p_subtotal - v_discount_amount, 2);

    RETURN v_total;
END;
$function$;

CREATE OR REPLACE FUNCTION billing_demo.validate_invoice_total()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_invoice_id integer;
    v_subtotal numeric;
    v_total numeric;
    v_status text;
    v_operation text;
BEGIN
    -- Scalar copies make the values easy to inspect in the Watches window.
    v_invoice_id := NEW.invoice_id;
    v_subtotal := NEW.subtotal;
    v_total := NEW.total;
    v_status := NEW.status;
    v_operation := TG_OP;

    IF v_status = 'finalized' THEN
        IF v_total IS NULL OR v_total < 0 OR v_total > v_subtotal THEN
            RAISE EXCEPTION 'Invoice % has invalid total: %', v_invoice_id, v_total
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE PROCEDURE billing_demo.finalize_invoice(p_invoice_id integer)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_subtotal numeric;
    v_discount_pct numeric;
    v_status text;
    v_total numeric;
BEGIN
    SELECT i.subtotal, i.discount_pct, i.status
      INTO v_subtotal, v_discount_pct, v_status
      FROM billing_demo.invoices AS i
     WHERE i.invoice_id = p_invoice_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invoice % was not found.', p_invoice_id
            USING ERRCODE = '22023';
    END IF;

    IF v_status <> 'draft' THEN
        RAISE EXCEPTION 'Invoice % is already finalized.', p_invoice_id
            USING ERRCODE = '55000';
    END IF;

    v_total := billing_demo.calculate_invoice_total(v_subtotal, v_discount_pct);

    UPDATE billing_demo.invoices
       SET total = v_total,
           status = 'finalized'
     WHERE invoice_id = p_invoice_id;
END;
$procedure$;

DROP TRIGGER IF EXISTS invoice_total_guard ON billing_demo.invoices;
CREATE TRIGGER invoice_total_guard
BEFORE INSERT OR UPDATE ON billing_demo.invoices
FOR EACH ROW
EXECUTE FUNCTION billing_demo.validate_invoice_total();
COMMIT;
