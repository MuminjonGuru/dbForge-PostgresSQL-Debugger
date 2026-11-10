-- SYNTHETIC DEMO ONLY. This script REPLACES billing_demo in dbforge_billing_million.
-- It creates 50,000 customers + 1,000,000 invoices using generate_series.
-- Run once before installing the buggy routines; it can take time and disk space.
BEGIN;
DO $guard$
BEGIN
    IF current_database() <> 'dbforge_billing_million' THEN
        RAISE EXCEPTION 'Refusing to seed database %; use dbforge_billing_million.', current_database();
    END IF;
END;
$guard$;

DROP SCHEMA IF EXISTS billing_demo CASCADE;
CREATE SCHEMA billing_demo;

CREATE TABLE billing_demo.customers (
    customer_id integer PRIMARY KEY,
    customer_name text NOT NULL,
    email text NOT NULL UNIQUE
);

CREATE TABLE billing_demo.invoices (
    invoice_id integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES billing_demo.customers(customer_id),
    subtotal numeric(12,2) NOT NULL CHECK (subtotal BETWEEN 0 AND 1000000),
    discount_pct numeric(5,2) NOT NULL CHECK (discount_pct BETWEEN 0 AND 100),
    total numeric(12,2),
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'finalized')),
    created_at timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT invoice_total_range CHECK (total IS NULL OR total BETWEEN 0 AND subtotal),
    CONSTRAINT invoice_status_total CHECK (
        (status = 'draft' AND total IS NULL)
        OR (status = 'finalized' AND total IS NOT NULL)
    )
);

INSERT INTO billing_demo.customers (customer_id, customer_name, email)
SELECT n,
       CASE n
           WHEN 1 THEN 'Northstar Labs'
           WHEN 2 THEN 'Cedar Studio'
           WHEN 3 THEN 'Orbit Learning'
           WHEN 4 THEN 'Harbor Apps'
           ELSE 'Customer ' || lpad(n::text, 5, '0')
       END,
       'customer' || n::text || '@example.test'
  FROM generate_series(1, 50000) AS n;

-- 80% finalized and 20% draft before reserving four demonstration invoices.
-- Monetary calculations use numeric, not floating-point data types.
WITH base AS (
    SELECT n AS invoice_id,
           ((n - 1) % 50000) + 1 AS customer_id,
           (10 + (n % 95000)::numeric / 100)::numeric(12,2) AS subtotal,
           (CASE n % 8
               WHEN 0 THEN 0
               WHEN 1 THEN 5
               WHEN 2 THEN 10
               WHEN 3 THEN 12.5
               WHEN 4 THEN 15
               WHEN 5 THEN 20
               WHEN 6 THEN 30
               ELSE 100
            END)::numeric(5,2) AS discount_pct,
           CASE WHEN n % 5 = 0 THEN 'draft' ELSE 'finalized' END AS status,
           timestamp '2024-01-01' + ((n % 730) * interval '1 day') AS created_at
      FROM generate_series(1, 1000000) AS n
)
INSERT INTO billing_demo.invoices
    (invoice_id, customer_id, subtotal, discount_pct, total, status, created_at)
SELECT invoice_id,
       customer_id,
       subtotal,
       discount_pct,
       CASE WHEN status = 'draft'
            THEN NULL
            ELSE round(subtotal - (subtotal * discount_pct / 100.0), 2)
       END AS total,
       status,
       created_at
  FROM base;

-- Four named examples, deliberately kept as drafts for the video.
UPDATE billing_demo.invoices
   SET customer_id = CASE invoice_id
                         WHEN 1001 THEN 1 WHEN 1002 THEN 2
                         WHEN 1003 THEN 3 ELSE 4 END,
       subtotal = CASE invoice_id
                      WHEN 1004 THEN 149.95 ELSE 200.00 END,
       discount_pct = CASE invoice_id
                          WHEN 1001 THEN 10.00
                          WHEN 1002 THEN 0.00
                          WHEN 1003 THEN 100.00
                          ELSE 12.50 END,
       total = NULL,
       status = 'draft'
 WHERE invoice_id BETWEEN 1001 AND 1004;

CREATE INDEX invoices_customer_id_idx ON billing_demo.invoices(customer_id);
CREATE INDEX invoices_status_idx ON billing_demo.invoices(status);
CREATE INDEX invoices_created_at_idx ON billing_demo.invoices(created_at);
COMMIT;

ANALYZE billing_demo.customers;
ANALYZE billing_demo.invoices;

SELECT (SELECT count(*) FROM billing_demo.customers) AS customers,
       (SELECT count(*) FROM billing_demo.invoices) AS invoices,
       (SELECT count(*) FROM billing_demo.invoices WHERE status = 'draft') AS drafts,
       (SELECT count(*) FROM billing_demo.invoices WHERE status = 'finalized') AS finalized;
-- Expected: 50000 | 1000000 | 200004 | 799996.
