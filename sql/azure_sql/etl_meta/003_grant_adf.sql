/*
  I let Azure Data Factory use the metadata database with its managed identity.
  ADF can read the etl schema (to look up which sources to run) and execute the
  stored procedures in it. It gets no direct INSERT, UPDATE or DELETE rights, so the
  only way it can change the audit table or a watermark is through usp_start_run and
  usp_finish_run, which enforce the rules.
  Run this in sqldb-etl-meta while signed in as the Entra admin.

  If CREATE USER fails because the name can't be resolved, use the Managed Identity Object ID
  from the factory's Properties page instead:
  CREATE USER [adf-carboncap-dev-zm] FROM EXTERNAL PROVIDER WITH OBJECT_ID = '<object id>';
*/

CREATE USER [adf-carboncap-dev-zm] FROM EXTERNAL PROVIDER;

GRANT SELECT ON SCHEMA::etl TO [adf-carboncap-dev-zm];

GRANT EXECUTE ON SCHEMA::etl TO [adf-carboncap-dev-zm];
