# ADR 0004: Choose the price provider with a Phase 0 test, behind a swappable `PriceSource` interface

- **Status:** Accepted (provider to be named after the test)
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
