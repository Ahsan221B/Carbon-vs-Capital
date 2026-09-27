# ADR 0003: Create infrastructure manually for now; codify it with Terraform in Phase 7

- **Status:** Accepted
- **Date:** 2026-09-28

## Context

Infrastructure as code (IaC) is the industry standard, and the brief lists it as a stretch goal. The developer is new to Azure's resource model, Unity Catalog and Snowflake. Learning an IaC tool at the same time would slow Phases 0–1 and hide what each resource actually does.

The stack spans three control planes: Azure, Databricks (workspace, Unity Catalog, jobs) and Snowflake.

## Decision

- **Phases 0–6:** create resources through the Azure portal and the Databricks and Snowflake UIs. Record each resource's name, SKU and key settings in `infra/SETUP_LOG.md`.
- **Phase 7:** codify the environment with **Terraform** (the azurerm, databricks and snowflake providers). Use the setup log as the specification, and prove the code works by recreating the environment in a fresh resource group.

## Alternatives considered

- **IaC from day one:** best practice, but it adds a second learning curve at the riskiest stage and makes early mistakes slower to fix.
- **Bicep:** Azure-native with a gentle syntax, but it can't manage Databricks Unity Catalog objects, Databricks jobs or Snowflake. Using it would mean running two tools.
- **Never codifying:** unacceptable for a project meant to be reproducible ("a stranger can follow the README").

## Consequences

- The environment can drift from what's written down until Phase 7, so the setup log has to be kept up to date.
- Teardown stays manual. The single resource group `rg-carbon-capital-dev` keeps it to one delete.
- Terraform state files contain secrets. They are git-ignored, and a remote backend (an Azure Storage container) will be used in Phase 7.
- Databricks Asset Bundles still deploy jobs from Phase 2 onward. Terraform covers only infrastructure.
