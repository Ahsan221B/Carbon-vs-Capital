/*
  I create the control table that drives the metadata driven ADF pipeline.
  Each row describes one thing to ingest: what it is, how to fetch it,
  where it lands in the landing container and how far the last successful run got.
  This runs in the database sqldb-etl-meta, never in the research database.

  In the portal Query editor, run the CREATE SCHEMA statement on its own first,
  then the CREATE TABLE statement. GO is a batch separator for tools like
  sqlcmd, SSMS and VS Code.
*/

CREATE SCHEMA etl;
GO

CREATE TABLE etl.source_control
(
    source_id         INT IDENTITY(1,1) NOT NULL,
    source_name       VARCHAR(100)      NOT NULL,
    source_type       VARCHAR(20)       NOT NULL,
    is_enabled        BIT               NOT NULL CONSTRAINT df_source_control_is_enabled DEFAULT (1),
    load_type         VARCHAR(20)       NOT NULL,
    run_group         VARCHAR(20)       NOT NULL CONSTRAINT df_source_control_run_group DEFAULT ('daily'),
    priority          SMALLINT          NOT NULL CONSTRAINT df_source_control_priority DEFAULT (100),
    endpoint_or_path  NVARCHAR(1000)    NOT NULL,
    sink_folder       NVARCHAR(400)     NOT NULL,
    watermark_type    VARCHAR(20)       NOT NULL CONSTRAINT df_source_control_watermark_type DEFAULT ('none'),
    watermark_value   NVARCHAR(200)     NULL,
    source_config     NVARCHAR(MAX)     NULL,
    last_run_status   VARCHAR(20)       NULL,
    last_success_at   DATETIME2(3)      NULL,
    created_at        DATETIME2(3)      NOT NULL CONSTRAINT df_source_control_created_at DEFAULT (SYSUTCDATETIME()),
    updated_at        DATETIME2(3)      NOT NULL CONSTRAINT df_source_control_updated_at DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT pk_source_control PRIMARY KEY (source_id),
    CONSTRAINT uq_source_control_source_name UNIQUE (source_name),
    CONSTRAINT ck_source_control_source_type
        CHECK (source_type IN ('http_file', 'rest_api', 'sql_table', 'databricks_job')),
    CONSTRAINT ck_source_control_load_type
        CHECK (load_type IN ('full', 'incremental')),
    CONSTRAINT ck_source_control_watermark_type
        CHECK (watermark_type IN ('none', 'release', 'date', 'lsn')),
    CONSTRAINT ck_source_control_incremental_needs_watermark
        CHECK (load_type = 'full' OR watermark_type <> 'none'),
    CONSTRAINT ck_source_control_last_run_status
        CHECK (last_run_status IS NULL OR last_run_status IN ('succeeded', 'failed', 'running')),
    CONSTRAINT ck_source_control_source_config_is_json
        CHECK (source_config IS NULL OR ISJSON(source_config) = 1)
);
GO
