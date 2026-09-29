# Setup log

Manual record of every cloud resource, in creation order. Resources are created by hand
until Phase 7, when this log becomes the specification for Terraform (see ADR 0003).

**Conventions**
- Region: East US 2 (ADR 0001)
- All resources live in `rg-carbon-capital-dev`, so deleting the resource group tears down the whole environment
- Tags on every resource: `project=carbon-vs-capital`, `env=dev`, `owner=zef`
- Naming: Microsoft Cloud Adoption Framework prefixes (`rg-`, `st`, `kv-`, `dbw-`, `adf-`, `sql-`)

---

## 2026-09-28 — Cost budget

| Setting | Value |
|---|---|
| Name | `cvc-monthly-budget` |
| Scope | Billing account |
| Amount | 20 USD / month (resets monthly) |
| Validity | 2026-09-01 to 2027-09-30 |
| Alerts | Actual 50% ($10), actual 80% ($16), actual 100% ($20), forecasted 100% ($20) |
| Recipient | Owner's email |

> The subscription is pay-as-you-go with **no spending limit**. The budget only sends alerts;
> it never stops resources. Cost control relies on auto-termination, auto-pause and auto-suspend
> settings on each resource.

---

## 2026-09-28 — Resource group

| Setting | Value |
|---|---|
| Name | `rg-carbon-capital-dev` |
| Region | East US 2 |

---

## 2026-09-28 — Storage account (ADLS Gen2)

| Setting | Value | Why |
|---|---|---|
| Name | `stcarboncapdevzm` | Globally unique; `st` prefix |
| Kind | StorageV2 (general purpose v2) | |
| Primary service | Azure Blob Storage or Azure Data Lake Storage | |
| Performance | Standard | Premium SSD gives batch workloads no benefit |
| Redundancy | LRS | Dev environment; landing data can be re-downloaded (see known limitations) |
| Hierarchical namespace | **Enabled** | Makes the account ADLS Gen2: real directories and atomic renames for Spark/Delta |
| Access tier | Hot | Data is read frequently; Cool charges per read and has a 30-day minimum |
| Secure transfer | Enabled | |
| Minimum TLS | 1.2 | |
| Blob anonymous access | Disabled | |
| Storage account key access | Enabled | To be disabled in Phase 7 hardening |
| Default to Entra authorization in portal | Enabled | The portal uses identity-based access, like the rest of the project |
| Cross-tenant replication | Disabled | |
| SFTP / NFS v3 | Disabled | |
| Public network access | Enabled from all networks | Private endpoints not used (cost) |
| Routing | Microsoft network routing | |
| Blob soft delete | Enabled, 7 days | |
| Container soft delete | Enabled, 7 days | |
| Versioning / change feed | Disabled | Delta keeps its own version history |
| Point-in-time restore | Disabled | |
| Encryption | Microsoft-managed keys | |
| Defender for Storage | Disabled | Cost (~$10/month per account) |

**Containers** (all with private access)

| Container | Purpose |
|---|---|
| `landing` | Source files exactly as received (zips, raw JSON), before conversion |
| `bronze` | Raw data as append-only Delta tables, with ingestion metadata |
| `silver` | Cleaned, conformed and matched Delta tables |
| `gold` | Star schema and metric tables |

**Access control (RBAC)**

| Principal | Role | Scope |
|---|---|---|
| Zef (user) | Storage Blob Data Contributor | Storage account |

> Being subscription Owner grants control-plane rights (manage the account) but **not**
> data-plane rights (read or write blobs using Entra authentication). The data role above is required.

**Estimated cost:** under $1/month at project scale (storage about $0.02/GB-month plus transactions).

---

## 2026-09-28 — Key Vault

| Setting | Value | Why |
|---|---|---|
| Name | `kv-carboncap-dev-zm` | Globally unique; `kv-` prefix |
| Region | East US 2 | |
| Pricing tier | Standard | Premium only adds HSM-backed keys; not needed |
| Permission model | Azure RBAC | Current recommendation; same role system as storage (not legacy access policies) |
| Soft-delete retention | 7 days (minimum) | Soft delete is mandatory; a deleted vault's name stays reserved during retention |
| Purge protection | Disabled | Would block permanent deletion until retention ends and can't be turned off again; enable in production |
| Resource access (VMs, ARM templates, disk encryption) | All disabled | Not used |
| Public network access | Enabled from all networks | Private endpoints not used (cost) |
| Tags | `project=carbon-vs-capital`, `env=dev`, `owner=zef` | |

**Access control (RBAC)**

| Principal | Role | Scope |
|---|---|---|
| Zef (user) | Key Vault Secrets Officer | Key Vault |

> As with storage: subscription Owner can manage the vault (control plane)
> but can't read or write secrets (data plane) without a data role.

**Secrets**

| Name | Purpose |
|---|---|
| `smoke-test` | Dummy value used to test Databricks → secret scope → Key Vault access. Delete after Phase 0 |

**Planned secrets:** Snowflake loader private key and passphrase (Phase 6), Stooq API key and
OpenFIGI API key (Phase 1). Azure SQL will use Entra-only authentication, so no SQL password is stored.

**Estimated cost:** effectively $0 (Standard tier: about $0.03 per 10,000 operations, no base fee).

---

## 2026-09-28 — Compute quota (East US 2)

Classic Databricks clusters run as virtual machines in this subscription, so they need
per-VM-family vCPU quota. New pay-as-you-go subscriptions start with 0 for most families.

**Resource providers registered** (free; required before quotas are visible or usable)

| Provider | Needed for |
|---|---|
| `Microsoft.Compute` | Virtual machines behind Databricks clusters; compute quotas |
| `Microsoft.Databricks` | Databricks workspace and access connector |
| `Microsoft.Network` | Virtual network created for the workspace |
| `Microsoft.Quota` | Quota increase requests from the portal |

**Quota requests**

| Family | Requested | Result |
|---|---|---|
| Standard DADSv5 | 8 vCPUs | Refused (self-service): "high in demand in East US 2" |
| Standard DDSv5 | 8 vCPUs | Refused (self-service), then **approved via support request `2609280030003568`** |
| Standard DSv5 | 8 vCPUs | Refused (self-service) |

**Current limits**

| Quota | Limit |
|---|---|
| Total Regional vCPUs | 10 |
| Standard DDSv5 Family vCPUs | **8** |
| Total Regional Low-priority (Spot) vCPUs | 3 (too low for a 4-vCPU node) |

**Cluster node type:** `Standard_D4ds_v5` (4 vCPUs, 16 GB RAM, local SSD).
The 8-vCPU quota allows at most two single-node clusters at once (one interactive, one job).
Compute strategy: ADR 0008 (supersedes ADR 0007). See "First compute" below: the SKU itself is
currently restricted for this subscription, which is a separate gate from quota.

> Notes
> - DSv3 is flagged End of Life by the portal; avoid it even though older tutorials use it.
> - v6 families have quota but aren't in Databricks' supported node type list.
> - Check quotas: `az vm list-usage --location eastus2 -o table | grep -i "DDSv5"`
> - Check SKU access: `az vm list-skus --location eastus2 --size Standard_D4ds_v5 --all -o table`

---

## 2026-09-29 — Azure Databricks workspace

| Setting | Value | Why |
|---|---|---|
| Name | `dbw-carboncap-dev` | `dbw-` prefix |
| Region | East US 2 | ADR 0001 |
| Pricing tier | Trial (Premium, 14 days of free DBUs) | Premium is required for Unity Catalog |
| **Trial ends** | **2026-10-13** | After this, DBUs are billed at the Premium rate |
| Workspace type | Hybrid (classic + serverless) | ADR 0008: classic by default; serverless used while classic SKUs are restricted |
| Managed resource group | `rg-carbon-capital-dev-dbw-managed` | Named explicitly instead of the auto-generated name |
| Secure cluster connectivity (No Public IP) | **Disabled** | Avoids an auto-created NAT gateway (~$30+/month, always on) |
| VNet injection | No | Databricks-managed network |
| Tags | `project=carbon-vs-capital`, `env=dev`, `owner=zef` | Inherited by clusters as default tags |

**Managed resource group contents** (locked by Databricks with a deny assignment; don't modify)

| Resource | Purpose |
|---|---|
| `workers-vnet`, `workers-sg` | Network and security rules for cluster VMs |
| `dbstorage…` | The workspace's internal storage |
| `dbmanagedidentity` | Identity Databricks uses internally |
| `unity-catalog-access-connector` | Auto-created access connector; **not used**, because we create our own (see below) |

**Unity Catalog:** enabled automatically; a regional metastore is attached.

| Catalog | Notes |
|---|---|
| `dbw_carboncap_dev` | Auto-created default workspace catalog, stored in managed storage; not used for project data |
| `system` | Databricks system tables (billing, audit, lineage) |
| `samples` | Read-only demo data shared by Databricks |

**Serverless Starter Warehouse** (auto-created)

| Setting | Value |
|---|---|
| Type / size | Serverless SQL, 2X-Small |
| Auto stop | 5 minutes |
| Scaling | Max 1 cluster |
| Note | Bills only while running; previewing data in Catalog Explorer can start it. Not needed, because Snowflake serves BI |

**Cluster policy: `carboncap-interactive-single-node`** (interactive clusters only; job-cluster policy in Phase 1)

| Rule | Value |
|---|---|
| Cluster type | All-purpose only |
| Topology | Single node (0 workers) |
| Node type | `Standard_D4ds_v5` (fixed) |
| Auto-termination | 15 minutes (fixed) |
| Photon | Off (`runtime_engine = STANDARD`) |
| Availability | On-demand (no Spot) |
| Runtime | Latest LTS by default |
| Access mode | Dedicated (`SINGLE_USER`), Unity Catalog-enabled |
| Tags | Not set in the policy; `project`, `env`, `owner` are inherited from the workspace's Azure tags (setting them in the policy caused a naming conflict) |

> A workspace admin can still create clusters outside the policy; it's a guardrail against mistakes.
> The 8-vCPU DDSv5 quota is the hard limit (at most two single-node clusters).

**Estimated cost:** workspace $0; managed storage cents per month; clusters billed only while running
(during the trial, mainly the VM, roughly $0.20–0.25/hour for D4ds_v5).

---

## 2026-09-29 — Access connector (Unity Catalog → ADLS)

| Setting | Value | Why |
|---|---|---|
| Name | `ac-carboncap-dev` | Our own connector, not the auto-created one in the locked managed resource group |
| Resource group | `rg-carbon-capital-dev` | Storage access survives a workspace rebuild; reusable by future workspaces |
| Region | East US 2 | |
| Identity | System-assigned managed identity | No keys or secrets; Azure issues and rotates tokens |
| Tags | `project=carbon-vs-capital`, `env=dev`, `owner=zef` | |

**Access control (RBAC) on `stcarboncapdevzm`**

| Principal | Role | Scope |
|---|---|---|
| Zef (user) | Storage Blob Data Contributor | Storage account |
| `ac-carboncap-dev` (managed identity) | Storage Blob Data Contributor | Storage account |

> Azure grants coarse account-level access to the connector; Unity Catalog enforces fine-grained,
> per-user access to catalogs, schemas, tables and external locations.

**Not used:** `unity-catalog-access-connector` in the managed resource group (auto-created with the workspace).

**Estimated cost:** $0.

---

## 2026-09-29 — Unity Catalog storage credential and external locations

**Storage credential**

| Name | Type | Identity | Purpose |
|---|---|---|---|
| `cred_carboncap_adls` | Azure Managed Identity | Access connector `ac-carboncap-dev` (system-assigned) | Unity Catalog's identity for reaching `stcarboncapdevzm` |

**External locations**

| Name | URL | Credential |
|---|---|---|
| `ext_landing` | `abfss://landing@stcarboncapdevzm.dfs.core.windows.net/` | `cred_carboncap_adls` |
| `ext_bronze` | `abfss://bronze@stcarboncapdevzm.dfs.core.windows.net/` | `cred_carboncap_adls` |
| `ext_silver` | `abfss://silver@stcarboncapdevzm.dfs.core.windows.net/` | `cred_carboncap_adls` |
| `ext_gold` | `abfss://gold@stcarboncapdevzm.dfs.core.windows.net/` | `cred_carboncap_adls` |

Test connection: read, list, write, delete, path exists and hierarchical namespace all passed.

**File events: not configured.** The test failed with 403 because the connector lacks Storage Account
Contributor, EventGrid EventSubscription Contributor and Storage Queue Data Contributor. Not granted
on purpose: Storage Account Contributor is a broad control-plane role (it can read account keys).
Auto Loader will use directory listing, which is fine at this file volume. Revisit in Phase 2.

> Pattern: Azure RBAC gives the connector coarse access to the storage account; Unity Catalog
> grants control per-user access per path. No mount points, storage keys or service principal secrets.

**Not used:** credential and external location `dbw_carboncap_dev` (auto-created for the default workspace catalog).

**Estimated cost:** $0 (metadata only).

---

## 2026-09-29 — Unity Catalog catalog, schemas and volume

| Object | Type | Storage |
|---|---|---|
| `carbon_capital` | Catalog (Standard) | `abfss://gold@stcarboncapdevzm.dfs.core.windows.net/_catalog_default` (fallback only) |
| `carbon_capital.bronze` | Schema (managed tables) | `abfss://bronze@stcarboncapdevzm.dfs.core.windows.net/managed` |
| `carbon_capital.silver` | Schema (managed tables) | `abfss://silver@stcarboncapdevzm.dfs.core.windows.net/managed` |
| `carbon_capital.gold` | Schema (managed tables) | `abfss://gold@stcarboncapdevzm.dfs.core.windows.net/managed` |
| `carbon_capital.landing` | Schema (volumes only) | none of its own |
| `carbon_capital.landing.raw` | External volume | `abfss://landing@stcarboncapdevzm.dfs.core.windows.net/files` |

- Tables are Unity Catalog **managed** tables stored in our own containers (not Databricks' internal storage).
- Code reads source files as `/Volumes/carbon_capital/landing/raw/...`; the physical path is never hard-coded.
- Managed locations and the volume use separate sibling sub-paths, because Unity Catalog forbids overlapping managed storage with external volumes.
- The auto-created `default` schema was deleted, so tables created without a schema fail instead of landing in the fallback location.
- Verified by uploading a test CSV through Catalog Explorer and finding it in the `landing` container.

**Estimated cost:** $0 (metadata only).

---

## 2026-09-29 — Key Vault-backed secret scope

| Setting | Value |
|---|---|
| Scope name | `kv-carboncap` |
| Backend | Azure Key Vault `kv-carboncap-dev-zm` (`https://kv-carboncap-dev-zm.vault.azure.net/`) |
| Manage principal | Creator |

**Access control (RBAC) on `kv-carboncap-dev-zm`**

| Principal | Role | Why |
|---|---|---|
| Zef (user) | Key Vault Secrets Officer | Create and manage secrets |
| AzureDatabricks (enterprise app `2ff814a6-3304-4ab8-85cb-cd0e6f879c1d`) | Key Vault Secrets User | Lets the secret scope read secrets (read-only) |

- Secrets stay in Key Vault (rotation and audit in Azure); code uses `dbutils.secrets.get("kv-carboncap", "<name>")`.
- Notebook output redacts secret values, but redaction is a convenience, not a security control:
  anyone who can run code with access to the scope can recover the value. The real protection is who can
  use the scope and the vault (scope permissions and Azure RBAC).
- The application (client) ID above is the same in every tenant; the service principal's object ID in our tenant is different. That's expected.

**Estimated cost:** $0.

---

## 2026-09-29 — First compute and end-to-end smoke test

**Classic cluster (blocked)**

| Setting | Value |
|---|---|
| Cluster | `carboncap-dev-interactive` (all-purpose, policy `carboncap-interactive-single-node`) |
| Result | Failed to start: `CLOUD_PROVIDER_RESOURCE_STOCKOUT` |
| Diagnosis | `az vm list-skus --location eastus2 --all`: D4ds_v5, D4ads_v5, D4s_v5, E4bds_v5 = `NotAvailableForSubscription` |
| Action | Support request to lift the SKU restriction (quota already approved in request 2609280030003568) |

> Three separate gates for Azure VMs: quota (vCPU permission), SKU access (per subscription and region), capacity.

**Smoke test on serverless compute** (scratch notebook, not committed)

| Check | Result |
|---|---|
| `dbutils.secrets.get("kv-carboncap", "smoke-test")` | Value read, redacted in output (length 19) |
| Write + read CSV via `/Volumes/carbon_capital/landing/raw/` | 2 rows read back; file visible in `landing/files/` |
| Managed Delta table in `carbon_capital.bronze` | Stored under `abfss://bronze@stcarboncapdevzm.dfs.core.windows.net/managed/__unitystorage/...` |
| Clean-up | Test table dropped, test files removed (verified in the Storage browser) |

Phase 0 done criterion met: a Databricks notebook reads a file from ADLS through Unity Catalog.

**Cost:** serverless, billed per second only while running (a few cents at most); verify in Cost Management.

---

## Known limitations (development environment)

- LRS only. Bronze contains data that can't be recreated later (CDC history, daily price snapshots); production would use ZRS or GZRS.
- No private endpoints; the storage account is reachable over the public internet (authentication still required).
- Defender for Storage is off.
- Storage account key access is still enabled.
- Key Vault is reachable over the public internet (no private endpoint); purge protection is off.
- Databricks workspace deployed without secure cluster connectivity (no NAT gateway, to avoid ~$30+/month);
  classic cluster nodes get public IP addresses, still behind network security rules.
- Unity Catalog file events not configured; Auto Loader uses directory listing.
- The access connector has account-wide Storage Blob Data Contributor; fine-grained access is enforced by Unity Catalog.
- The AzureDatabricks app can read every secret in the vault (acceptable: the vault is dedicated to this project).
- Classic VM sizes are restricted for this subscription in East US 2; development runs on serverless until lifted (ADR 0008 update).
- The cluster policy is a guardrail against mistakes; a workspace admin can still create clusters outside it.

## Teardown

- **Everything:** delete `rg-carbon-capital-dev`. Soft-deleted blobs are kept (and billed) for 7 days.
- **Budget:** lives at billing-account scope, so delete it separately in Cost Management.
- A deleted Key Vault stays soft-deleted for 7 days and its name stays reserved. To reuse the name
  sooner, purge it: Key Vaults → Manage deleted vaults → Purge.
- Deleting the Databricks workspace also deletes its managed resource group.