-- Run AFTER 02_install_buggy_routines.sql, BEFORE Compile for Debugging.
-- Deliberately fails with SQLSTATE 23514: Invoice 1001 has invalid total: -1800.00
-- Run independently in autocommit mode, not inside a larger transaction.
CALL billing_demo.finalize_invoice(1001);
-- Then run 05_inspect_data.sql; invoice 1001 remains a draft.
