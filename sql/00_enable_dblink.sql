-- Optional debugger prerequisite. PostgreSQL 11+; may require superuser rights.
-- Run in dbforge_billing_million, not the default postgres database.
DO $guard$
BEGIN
    IF current_database() <> 'dbforge_billing_million' THEN
        RAISE EXCEPTION 'Wrong database: %', current_database();
    END IF;
END;
$guard$;

CREATE EXTENSION IF NOT EXISTS dblink;
-- Then use dbForge Studio: Debug > Deploy Debug Engine.
-- dbForge deploys its own cr_debug schema; do not create it manually.
