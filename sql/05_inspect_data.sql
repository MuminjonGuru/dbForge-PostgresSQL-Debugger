-- Counts of the million-invoice demo (the totals change only after finalizing examples).
SELECT status, count(*) AS invoice_count
  FROM billing_demo.invoices
 GROUP BY status
 ORDER BY status;

SELECT count(*) AS customers FROM billing_demo.customers;
SELECT count(*) AS invoices FROM billing_demo.invoices;

-- Four invoices used in the recorded debugging walkthrough.
SELECT i.invoice_id, c.customer_name, i.subtotal, i.discount_pct,
       i.total, i.status
  FROM billing_demo.invoices AS i
  JOIN billing_demo.customers AS c ON c.customer_id = i.customer_id
 WHERE i.invoice_id BETWEEN 1001 AND 1004
 ORDER BY i.invoice_id;
