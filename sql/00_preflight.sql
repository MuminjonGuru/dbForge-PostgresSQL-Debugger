-- READ-ONLY checks: connect to dbforge_billing_million first.
SELECT current_database() AS current_database,
       current_setting('server_version') AS postgresql_version;

SELECT name, default_version, installed_version
  FROM pg_available_extensions
 WHERE name = 'dblink';

SELECT n.nspname || '.' || p.proname AS routine,
       pg_get_function_identity_arguments(p.oid) AS arguments
  FROM pg_proc AS p
  JOIN pg_namespace AS n ON n.oid = p.pronamespace
 WHERE n.nspname = 'billing_demo'
   AND p.prosrc LIKE '%cr_debug%'
 ORDER BY 1, 2;
-- Expected before setup: the last query returns no routines.
-- After debugging, it should be empty again after ordinary Compile.
