# ADR 0004: Choose the price provider with a Phase 0 test, behind a swappable `PriceSource` interface

- **Status:** Accepted (provider chosen 2026-10-01, see the update at the end)
- **Date:** 2026-09-28

## Context

Daily prices (OHLCV and adjusted close) are needed for returns and volatility (FR-16). Both free candidates in the brief have become unreliable in 2026:

- **yfinance:** an unofficial wrapper around Yahoo Finance endpoints. Users report HTTP 429 (rate limit) errors, and IP addresses from cloud providers tend to be blocked more.
- **Stooq:** has required an API key for CSV downloads since March 2026. There are also reports of a JavaScript proof-of-work challenge blocking scripted access.

Free providers change their terms without notice, so whichever provider we pick is likely to change during the project's lifetime.

## Decision

1. **Phase 0 test:** fetch about 3 years of daily history for 20 tickers from each candidate, running from both the laptop and a Databricks cluster. Record success rate, time taken, gaps and how adjusted close is defined.
2. **Adapter pattern:** ingestion code depends on a `PriceSource` interface, `fetch(tickers, start, end) -> DataFrame` with a fixed output schema. Each provider is a separate implementation, and the active one is chosen in config.
3. **Preference if both pass:** Stooq with an API key (a simple CSV and a clearer access model), with yfinance as the fallback implementation.

## Alternatives considered

- **Commit to yfinance now:** fastest to start with, but likely to fail in scheduled cloud runs, and it relies on Yahoo endpoints that aren't officially offered for this use.
- **Paid or registered free-tier APIs (for example Tiingo, Alpha Vantage):** more stable, but free-tier call limits may not cover 200–500 tickers daily. Kept as the next fallback if both candidates fail the test.

## Consequences

- Switching provider is a config change plus one new class, not a pipeline rewrite. This is also a good interview talking point.
- Bronze stores the provider name in each row, so data from different providers can be told apart.
- This ADR will be updated with the test results and the chosen provider.

## Update, 2026-10-01: test results and chosen provider

I ran the Phase 0 test on 20 tickers across our sectors (utilities, oil and gas, steel, building materials and chemicals) for January 2023 to December 2025. The code and full results are in `notebooks/exploration/03_price_source_test.ipynb`.

| Provider | From my laptop | From Databricks serverless | Notes |
|---|---|---|---|
| yfinance | 20 of 20 tickers, 752 rows each, about 1.7 s per ticker | 5 of 5 tickers, 752 rows each | Returns both `Close` and `Adj Close` |
| Stooq | 0 of 20 | not tested | Every request returned an HTML page instead of a CSV |

Stooq now needs an API key and a browser check, and I could not find any working way to request a key. A scheduled job can't get past a browser check, so Stooq is not usable for an unattended pipeline, even though its data is fine when viewed in a browser.

**Decision:** yfinance is the provider for v1, implemented as the first `PriceSource`. Yahoo was not blocking cloud IP addresses at the time of the test, so ingestion can run in Databricks.

**Risks and how we handle them:**

* yfinance is an unofficial wrapper and Yahoo can change or rate limit its endpoints at any time. The job requests one ticker at a time with a short pause, retries with backoff, and fails loudly instead of writing empty data.
* Every bronze row records the provider name, so a later switch is visible in the data.
* If yfinance stops working, the next candidate is a registered free tier API such as Tiingo, added as a second `PriceSource`.
* The prices are used for analysis in a personal portfolio project, not redistributed.
* We store both raw `Close` and `Adj Close`. Returns and volatility use `Adj Close` so splits and dividends don't show up as fake price jumps.
