# Public release candidate validation

Validation date: 21 November 2026.

## Simplified public data model

The public runtime uses the versioned bundle
`insee_2026-11-17_grid500_privacy_v6_simplified` and exactly three RDS files:

- `stock_aggregates.rds`: 18 current-stock section totals, seven
  municipality-wide creation-period cohorts and aggregate geocoding-flow
  counts;
- `spatial_aggregates.rds`: 286 released 500 m cell/section combinations in 51
  cells, representing 4,272 establishments;
- `history_yearly.rds`: the unchanged municipality-wide annual register-event
  series for 1973–2026.

The public bundle contains neither `history_section_3year.rds` nor
`creation_year_section`. Historical events have no public economic-section or
spatial dimension. Creation cohorts have no section, grid, geocoding, legal-form
or other establishment dimension.

## Runtime boundary

Shiny autoloads only `R/app_runtime.R`. Pipeline, geocoding and internal
historical-review functions remain outside the deployment. The deployment
allowlist contains exactly nine files and no raw, processed, internal,
reference, cache, establishment-row or source-geometry artifact.

## Public data and privacy checks

- 14,213 active establishments and 18 NAF sections;
- seven creation cohorts with counts 42, 999, 1,406, 1,473, 2,199, 4,677 and
  3,417, summing to 14,213;
- 5,214 address-exact O/O records in the internal aggregation basis;
- 4,272 spatially represented records in 286 released combinations and 51
  cells, with every published spatial count at least five;
- no establishment rows, original coordinates, uncut cell totals, suppressed
  spatial residuals, SIREN/SIRET, names or addresses;
- no year-by-section creation table and no protected or unprotected historical
  section table;
- the annual history is byte-identical to the validated predecessor and marks
  2026 as incomplete through 17 November.

Seventeen early municipality-wide annual closure or reopening values are below
five. They are retained because they contain no economic section, location or
establishment attribute. The spatial `n >= 5` rule is not claimed as a
universal threshold for every public statistic.

## Reproducibility and remaining limitation

`renv.lock` records R 4.4.2. The public app performs no live SIRENE, BAN or IGN
request. A complete clean-machine `renv::restore()` has not yet been performed;
platform-specific installation remains a release limitation.

The repository can start and test the app from the three supplied aggregate
files. It does not claim an end-to-end public rebuild of those aggregates:
official source/reference holdings and reviewed internal geocoding and spatial
preparation inputs are intentionally excluded.

The public repository and deployment are built only from their explicit
allowlists. Internal historical section analyses, unsafe predecessor bundles
and row-level reproduction artifacts are not allowlisted.

## Validation results

- complete local test suite: 230 passed, 0 failed, 0 warnings, 0 skipped;
- isolated public test suite: 160 passed, 0 failed, 0 warnings, 0 skipped;
- isolated Shiny application construction: passed;
- isolated construction under `en_US.UTF-8`: passed;
- isolated construction under non-UTF-8 `en_US.US-ASCII`: passed;
- public repository allowlist: 40 unique files;
- shinyapps.io deployment allowlist: 9 unique files.

Browser checks covered the dashboard, the unchanged aggregate map, the two
annual history charts, the seven creation cohorts and the narrow mobile view.
At 390 px the established fixed-width dashboard remains usable through
horizontal scrolling, but it is not a fully reflowing mobile layout.
