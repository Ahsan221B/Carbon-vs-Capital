# ADR 0007: Use Databricks serverless compute for development; add classic job clusters when quota allows

- **Status:** Accepted
- **Date:** 2026-09-28

## Context

The plan was single-node classic job clusters (brief section 8) on a 4-vCPU general-purpose VM.
Classic Databricks compute runs as virtual machines in our own Azure subscription, so it needs
per-VM-family vCPU quota. On this new pay-as-you-go subscription in East US 2:

- Total regional vCPU quota is 10, but every general-purpose v5 family (DSv5, DDSv5, DASv5, DADSv5) has a quota of 0.
- Self-service increases to 8 vCPUs were refused for DADSv5 ("high in demand in East US 2"), DDSv5 and DSv5.
- The older DSv3 family is marked End of Life, and v6 families (which do have quota) are not in Databricks' supported node type reference.

A support request has been filed but has no guaranteed turnaround.

Databricks serverless compute runs in a compute plane inside Databricks' own account, in the same
region as the workspace, so it doesn't use our subscription's VM quota.

## Decision

- Use **serverless compute** for notebooks and jobs during development (Phases 0–2 at least).
- Keep the pending quota request. When classic quota is granted, run at least one pipeline on a
  single-node classic **job cluster** under a cluster policy, and compare cost and runtime with serverless.
- The workspace is Premium tier with Unity Catalog (required for serverless and for our governance design).

## Alternatives considered

- **Wait for the quota:** blocks all Databricks work for an unknown time.
- **Another region:** breaks ADR 0001 (Snowflake co-location, Azure SQL free-offer region lock), and quota there isn't guaranteed either.
- **v6 or memory-optimised (E-series) VMs that already have quota:** v6 isn't in Databricks' supported list;
  E-series costs more per hour for memory we don't need.
- **Databricks Free Edition:** serverless-only and free, but it can't connect to our ADLS account, Key Vault or ADF.

## Consequences

- **Cost:** no idle clusters, and we pay only while code runs, which removes the biggest cost risk on
  pay-as-you-go. The per-DBU rate is higher than classic because infrastructure is included.
  Guardrails: a serverless budget policy for cost attribution, and notebook execution timeouts.
- **Feature limits we accept:** Python and SQL only (no R); Spark Connect APIs only (no RDD);
  no `df.cache()` or `persist()`; limited Spark configuration; no init scripts or JAR libraries in notebooks;
  no Spark UI. Our PySpark DataFrame, SQL, Auto Loader and MERGE workloads fit within these.
  `rapidfuzz` is installed per notebook with `%pip`.
- **Orchestration:** ADF will trigger **Databricks jobs** (which can run on serverless) rather than
  notebook activities bound to a cluster. Confirm in Phase 1.
- **Learning gap:** cluster sizing and cluster policies aren't exercised until classic quota arrives;
  tracked as a follow-up.