# ADR 0002: Load gold tables into Snowflake with the Spark connector and MERGE

- **Status:** Accepted
- **Date:** 2026-09-28

## Context

Snowflake serves the gold star schema to Power BI (FR-18 to FR-21), so dashboard queries never use Databricks compute. Gold tables are Delta tables in ADLS Gen2. There are two broad ways to make them queryable in Snowflake:

1. **Copy:** push gold rows into native Snowflake tables.
2. **Read in place:** Snowflake queries the lake files directly, either as external tables or as Iceberg tables. Delta tables can expose Iceberg metadata through Delta UniForm.

The Snowflake trial lasts about 30 days, so any time spent debugging the integration comes straight out of that window.

## Decision

For v1, a Databricks job writes each gold table to a `STAGING` table in Snowflake using the Snowflake Spark connector. It then runs a `MERGE` into `MARTS` on the table's business key. The loader authenticates with a key pair whose private key is stored in Key Vault.

## Alternatives considered

- **Iceberg tables over the lake (Delta UniForm plus a Snowflake catalog integration):**
  - Pros: no second copy of the data, no load job, and Snowflake always reads the latest gold.
  - Cons: needs an external volume, a catalog integration and UniForm configuration, all newer features with more ways to fail. Snowflake scans remote files on each query, so performance depends on how the lake files are laid out. Access has to be managed in both Unity Catalog and Snowflake.
- **External tables (Parquet):** read-only and slower than native or Iceberg tables. They don't understand Delta's transaction log, so Snowflake could read uncommitted or deleted files.
- **ADF copy activity into Snowflake:** workable, but it duplicates logic that already lives in Databricks. It also makes idempotent MERGE harder to express.

## Consequences

- A second copy of gold lives in Snowflake. Storage costs are negligible at this data size.
- Loads must be idempotent: MERGE on business keys, so rerunning a load doesn't duplicate rows (FR-17).
- Snowflake data is only as fresh as the last load. The dashboard shows a data freshness date.
- Iceberg over the lake stays documented as the upgrade path. A possible extension is to rebuild one table that way and compare cost and freshness.
