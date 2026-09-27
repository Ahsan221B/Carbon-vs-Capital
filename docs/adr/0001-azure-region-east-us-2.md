# ADR 0001: Deploy all Azure resources in East US 2

- **Status:** Accepted
- **Date:** 2026-09-28

## Context

The project runs on a personal pay-as-you-go Azure subscription, so cost matters more than latency. There is no Azure region in Pakistan, where the developer is based. Every workload is batch, so the distance between the developer and the region makes no practical difference.

Snowflake (Phase 6) reads gold data that Databricks writes to ADLS Gen2. When that data crosses Azure regions, Azure charges for the outbound transfer (egress). Snowflake on Azure is offered in East US 2 but not in East US.

The Azure SQL Database free offer fixes the region of every free database in a subscription once the first one is created.

## Decision

Deploy all resources in **East US 2**: the resource group, ADLS Gen2, Key Vault, Data Factory, Databricks and Azure SQL. Create the Snowflake account on Azure East US 2 as well.

## Alternatives considered

- **East US:** similar pricing, but Snowflake isn't available there on Azure, so gold-to-Snowflake traffic would cross regions.
- **UAE North or Central India:** geographically closer. Neither is an available Snowflake-on-Azure region, prices are typically higher, and closeness brings no benefit for batch jobs.
- **West Europe:** no advantage over East US 2 and typically more expensive.

## Consequences

- Traffic from the lake to Snowflake stays inside one region, so there are no egress charges. Reading Iceberg tables directly from the lake (see ADR 0002) remains a viable option.
- The Azure SQL free offer is now tied to East US 2 for this subscription.
- Portal access and interactive debugging from Pakistan have roughly 250 ms of network latency, which is acceptable.
- Microsoft sometimes restricts capacity in popular regions. If a virtual machine size isn't available, pick another size in the same region; don't split the project across regions.
