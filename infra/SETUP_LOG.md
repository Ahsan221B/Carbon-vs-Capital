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

## Known limitations (development environment)

- LRS only. Bronze contains data that can't be recreated later (CDC history, daily price snapshots); production would use ZRS or GZRS.
- No private endpoints; the storage account is reachable over the public internet (authentication still required).
- Defender for Storage is off.
- Storage account key access is still enabled.

## Teardown

- **Everything:** delete `rg-carbon-capital-dev`. Soft-deleted blobs are kept (and billed) for 7 days.
- **Budget:** lives at billing-account scope, so delete it separately in Cost Management.