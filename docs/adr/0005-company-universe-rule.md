# ADR 0005: Define the v1 company universe by rule; finalise the list after exploring the data

- **Status:** Accepted (updated 2026-10-01, see the update at the end)
- **Date:** 2026-09-28

## Context

v1 targets about 200–500 US-listed companies. How many can be used in practice depends on how completely Climate TRACE ownership data links to listed parents, and that is only known after exploring the data. Revenue comes from SEC company facts, which are reliable only for domestic filers that file form 10-K. Corporate events such as delistings and acquisitions (for example Nippon Steel's acquisition of U.S. Steel) change the universe over time.

## Decision

**Rule for inclusion:** US-domiciled companies filing form 10-K with the SEC, in these sectors:

- power and utilities
- oil and gas
- steel and metals
- cement and building materials
- chemicals

**Target size:** about 200–250 companies.

**Finalising the list:** at the end of Phase 0, after exploring Climate TRACE ownership coverage. The finished list is seeded into the Azure SQL `company_universe` table, where analysts maintain it and changes flow through CDC.

**Aviation** is provisionally excluded. The exploration will check whether Climate TRACE assigns aviation emissions to airports, whose owners are airport authorities, rather than to airlines. If it does, aviation emissions can't be attributed to listed companies at the facility level.

## Alternatives considered

- **A hand-picked fixed list now:** fast, but we might choose companies that turn out to have no attributable facilities.
- **Every US 10-K filer:** too large for v1, and most companies have no direct emissions.
- **Including foreign filers (forms 20-F and 40-F):** deferred, because SEC revenue data for them is inconsistent.

## Consequences

- Coverage is reported honestly: the share of universe emissions attributed to a listed company.
- Companies that leave the universe are handled by the SCD2 `dim_company` dimension, not deleted.
- Sector mapping must be kept consistent. The SIC codes from SEC filings are the source, mapped to our five sectors in a small reference table.

## Update, 2026-10-01

The Phase 0 exploration (notebooks 01 and 02) answered the questions this ADR left open. The inclusion rule stands, but part of the reasoning has changed.

**Aviation stays out of v1, for a different reason.** In the emissions file, aviation emissions are recorded against airports. The ownership file, however, lists the airlines operating at each airport and their share of its activity, and those shares add up to 100% at all 825 airport sources. So aviation emissions can be attributed to airlines after all. We still leave aviation out of v1 because that attribution is based on share of operations, while every other sector is attributed by equity ownership, and ranking companies on two different bases would need careful explanation. Aviation is a candidate for v2, shown separately with its own method note.

**Oil and gas is covered through refining only.** Oil and gas production and oil and gas transport have no ownership data in release v5.11.0. Together they account for about 3,090 Mt of emissions from 2021 to 2025, roughly 21% of the emissions in our sectors. These sources stay in the data and are reported as unattributable at facility level in the coverage figures, rather than being dropped. Refining (134 facilities) and petrochemical steam cracking (34 facilities) have full ownership coverage.

**Other subsectors have no owners either.** Lime, glass, other chemicals and other metals have no ownership data, so in practice cement and building materials means cement, and chemicals and metals are covered only through the subsectors that do have owners. Across all subsectors in scope, 72.9% of emissions can be linked to at least one owner.

**What this means for building the universe.** Companies will be matched to Climate TRACE owners on LEI and PermID, which about 97% of company owners carry. How emissions are attributed to a company is a separate decision, recorded in its own ADR, because the ownership file also includes investors that sit above the company owning the facility.
