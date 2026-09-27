# ADR 0005: Define the v1 company universe by rule; finalise the list after exploring the data

- **Status:** Accepted
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
