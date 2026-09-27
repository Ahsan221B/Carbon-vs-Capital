# ADR 0006: Store the Power BI report as a Power BI Project (.pbip), not .pbix

- **Status:** Accepted (changes the brief's deliverable from ".pbix plus screenshots")
- **Date:** 2026-09-28

## Context

The brief asks for the Power BI report to be committed to the public repo. A `.pbix` file is a single binary. In import mode it also contains a copy of the model's data, which makes it large, impossible to review in a pull request, and a way for data to leak into Git.

## Decision

Save the report as a **Power BI Project (`.pbip`)**. The report definition and semantic model are stored as text files (JSON and TMDL) that Git can diff. The following local-only files are git-ignored:

- `.pbi/localSettings.json`
- `.pbi/cache.abf`, which holds the cached data

Screenshots of each report page go in `powerbi/screenshots/`.

## Alternatives considered

- **Commit the `.pbix`:** the simplest option, but the file is binary, can't be reviewed, and contains data.
- **Screenshots only:** hides the DAX and the model design, which are part of what reviewers want to see.

## Consequences

- DAX measures and model changes can be reviewed like code in pull requests.
- Anyone cloning the repo must refresh the report against their own Snowflake account to see data.
- If a single-file download is needed, a `.pbix` can still be exported for a GitHub Release, kept out of Git history.
