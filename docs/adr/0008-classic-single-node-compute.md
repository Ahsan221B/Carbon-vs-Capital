# ADR 0008: Use classic single-node clusters as the default Databricks compute

- **Status:** Accepted (supersedes ADR 0007)
- **Date:** 2026-09-28

## Context

ADR 0007 chose serverless compute because the subscription had no quota for any general-purpose
v5 VM family in East US 2. Support request 2609280030003568 was approved the same day: Standard DDSv5
quota is now 8 vCPUs (regional total 10). The constraint behind ADR 0007 no longer exists.

## Decision

- **Interactive development:** one all-purpose, single-node cluster on `Standard_D4ds_v5`
  (4 vCPUs, 16 GB, local SSD), auto-terminating after 15 minutes idle.
- **Scheduled pipelines:** single-node job clusters on `Standard_D4ds_v5`, created per run.
- **Guardrail:** a cluster policy restricts all clusters to single node, the D4ds_v5 node type,
  mandatory auto-termination and project tags. No cluster is created before the policy exists.
- The workspace stays Hybrid, so serverless remains available for an optional cost comparison.

## Alternatives considered

- **Keep serverless as the default (ADR 0007):** instant startup and no idle cost, but a higher per-DBU
  rate, unconfirmed trial coverage, and no Spark UI, caching or Spark configuration, all of which this
  project is meant to demonstrate.
- **Multi-node clusters:** unnecessary for our data volume, and limited by the 8-vCPU quota.

## Consequences

- During the 14-day Premium trial, classic DBUs are free, so compute cost is mainly the VM.
- The idle-cluster risk is controlled by the policy's auto-termination; the quota caps us at two clusters at once.
- Cluster startup takes a few minutes; this is acceptable for batch work.
- Nodes get public IP addresses because secure cluster connectivity is disabled to avoid NAT gateway
  cost (see setup log, known limitations).