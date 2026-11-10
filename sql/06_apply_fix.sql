-- Stop debugging and use ordinary Compile to remove debug instrumentation first.
-- Then run this entire file independently (do NOT paste only the body into the editor).
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

    -- FIX: discounts use the 0-100 percentage scale.
    v_discount_amount := p_subtotal * p_discount_pct / 100.0;
    v_total := round(p_subtotal - v_discount_amount, 2);

    RETURN v_total;
END;
$function$;
COMMIT;
