/*
  I create the audit table and the two stored procedures that every ADF child pipeline calls.

  etl.pipeline_run_audit keeps one row per child pipeline run, so I can always answer
  what ran, when, how many rows moved and why something failed (FR5).

  etl.usp_start_run opens an audit row before the copy starts.
  etl.usp_finish_run closes it afterwards. When the run succeeded it also advances the
  watermark in etl.source_control, inside the same transaction. When the run failed the
  watermark is left alone. Keeping both writes in one procedure means the audit record and
  the watermark can never disagree, and the watermark only ever moves after a successful copy.

  This runs in sqldb-etl-meta. In the portal Query editor, run the CREATE TABLE statement
  and each CREATE OR ALTER PROCEDURE statement on its own, without the GO lines.
*/

CREATE TABLE etl.pipeline_run_audit
(
    audit_id          BIGINT IDENTITY(1,1) NOT NULL,
    pipeline_run_id   VARCHAR(64)          NOT NULL,
    master_run_id     VARCHAR(64)          NULL,
    pipeline_name     VARCHAR(200)         NOT NULL,
    source_id         INT                  NOT NULL,
    status            VARCHAR(20)          NOT NULL CONSTRAINT df_run_audit_status DEFAULT ('running'),
    started_at        DATETIME2(3)         NOT NULL CONSTRAINT df_run_audit_started_at DEFAULT (SYSUTCDATETIME()),
    ended_at          DATETIME2(3)         NULL,
    rows_read         BIGINT               NULL,
    rows_written      BIGINT               NULL,
    watermark_before  NVARCHAR(200)        NULL,
    watermark_after   NVARCHAR(200)        NULL,
    error_message     NVARCHAR(4000)       NULL,

    CONSTRAINT pk_run_audit PRIMARY KEY (audit_id),
    CONSTRAINT uq_run_audit_pipeline_run_id UNIQUE (pipeline_run_id),
    CONSTRAINT fk_run_audit_source FOREIGN KEY (source_id) REFERENCES etl.source_control (source_id),
    CONSTRAINT ck_run_audit_status CHECK (status IN ('running', 'succeeded', 'failed')),
    CONSTRAINT ck_run_audit_rows CHECK ((rows_read IS NULL OR rows_read >= 0) AND (rows_written IS NULL OR rows_written >= 0)),
    CONSTRAINT ck_run_audit_times CHECK (ended_at IS NULL OR ended_at >= started_at)
);
GO

CREATE INDEX ix_run_audit_source_started ON etl.pipeline_run_audit (source_id, started_at DESC);
GO

CREATE OR ALTER PROCEDURE etl.usp_start_run
    @pipeline_run_id VARCHAR(64),
    @master_run_id   VARCHAR(64) = NULL,
    @pipeline_name   VARCHAR(200),
    @source_id       INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    INSERT INTO etl.pipeline_run_audit (pipeline_run_id, master_run_id, pipeline_name, source_id, watermark_before)
    SELECT @pipeline_run_id, @master_run_id, @pipeline_name, sc.source_id, sc.watermark_value
    FROM etl.source_control AS sc
    WHERE sc.source_id = @source_id;

    IF @@ROWCOUNT = 0
        THROW 50001, 'usp_start_run: unknown source_id.', 1;

    UPDATE etl.source_control
    SET last_run_status = 'running',
        updated_at      = SYSUTCDATETIME()
    WHERE source_id = @source_id;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_finish_run
    @pipeline_run_id VARCHAR(64),
    @status          VARCHAR(20),
    @rows_read       BIGINT         = NULL,
    @rows_written    BIGINT         = NULL,
    @new_watermark   NVARCHAR(200)  = NULL,
    @error_message   NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @status NOT IN ('succeeded', 'failed')
        THROW 50002, 'usp_finish_run: status must be succeeded or failed.', 1;

    DECLARE @source_id INT;

    BEGIN TRANSACTION;

    SELECT @source_id = source_id
    FROM etl.pipeline_run_audit WITH (UPDLOCK)
    WHERE pipeline_run_id = @pipeline_run_id
      AND status = 'running';

    IF @source_id IS NULL
        THROW 50003, 'usp_finish_run: no running audit row for this pipeline_run_id.', 1;

    UPDATE etl.pipeline_run_audit
    SET status          = @status,
        ended_at        = SYSUTCDATETIME(),
        rows_read       = @rows_read,
        rows_written    = @rows_written,
        watermark_after = CASE WHEN @status = 'succeeded' THEN COALESCE(@new_watermark, watermark_before) ELSE watermark_before END,
        error_message   = @error_message
    WHERE pipeline_run_id = @pipeline_run_id;

    IF @status = 'succeeded'
        UPDATE etl.source_control
        SET watermark_value = COALESCE(@new_watermark, watermark_value),
            last_run_status = 'succeeded',
            last_success_at = SYSUTCDATETIME(),
            updated_at      = SYSUTCDATETIME()
        WHERE source_id = @source_id;
    ELSE
        UPDATE etl.source_control
        SET last_run_status = 'failed',
            updated_at      = SYSUTCDATETIME()
        WHERE source_id = @source_id;

    COMMIT TRANSACTION;
END;
GO
