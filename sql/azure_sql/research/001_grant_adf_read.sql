/*
  I let Azure Data Factory read the research database with its managed identity.
  ADF only ever reads this database, so it gets db_datareader and nothing more.
  Run this in sqldb-research while signed in as the Entra admin.

  If CREATE USER fails because the name can't be resolved, use the Managed Identity Object ID
  from the factory's Properties page instead:
  CREATE USER [adf-carboncap-dev-zm] FROM EXTERNAL PROVIDER WITH OBJECT_ID = '<object id>';
*/

CREATE USER [adf-carboncap-dev-zm] FROM EXTERNAL PROVIDER;

ALTER ROLE db_datareader ADD MEMBER [adf-carboncap-dev-zm];
