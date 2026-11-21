# Public release candidate validation

Validation date: 21 November 2026.

## Simplified public data model

The public runtime uses the versioned bundle
`insee_2026-11-17_grid500_privacy_v6_simplified` and exactly four RDS files:

- `stock_aggregates.rds`: 18 current-stock section totals, seven
  municipality-wide creation-period cohorts and aggregate geocoding-flow
  counts;
- `spatial_aggregates.rds`: 286 released 500 m cell/section combinations in 51
  cells, representing 4,272 establishments;
- `history_yearly.rds`: the unchanged municipality-wide annual register-event
  series for 1973–2026;
- `creation_year_top8.rds`: the additional reviewed file in the existing
  v6-named bundle, containing exactly 96 approved values for 2015–2026 and the eight
  largest current NAF sections.

The public bundle contains neither `history_section_3year.rds` nor the complete
`creation_year_section` table. Historical events have no public economic-section
or spatial dimension. Creation cohorts have no section, grid, geocoding,
legal-form or other establishment dimension. The separate Top-8 table has no
establishment, spatial, legal-form or person-type field.

## Runtime boundary

Shiny autoloads only `R/app_runtime.R`. Pipeline, geocoding and internal
historical-review functions remain outside the deployment. The deployment
allowlist contains exactly ten files and no raw, processed, internal,
reference, cache, establishment-row or source-geometry artifact.

## Public data and privacy checks

- 14,213 active establishments and 18 NAF sections;
- seven creation cohorts with counts 42, 999, 1,406, 1,473, 2,199, 4,677 and
  3,417, summing to 14,213;
- eight largest current sections L, G, S, F, Q, M, N and R, independently
  reconciled to 11,247 active establishments;
- 96 Top-8 creation-year values for 2015–2026, with no missing combination and
  a minimum published count of 13;
- 5,214 address-exact O/O records in the internal aggregation basis;
- 4,272 spatially represented records in 286 released combinations and 51
  cells, with every published spatial count at least five;
- no establishment rows, original coordinates, uncut cell totals or suppressed
  residuals for individual grid cells, SIREN/SIRET, names or addresses;
- no complete year-by-section creation table and no protected or unprotected
  historical-event section table;
- the annual history is byte-identical to the validated predecessor and marks
  2026 as incomplete through 17 November.

Seventeen early municipality-wide annual closure or reopening values are below
five. They are retained because they contain no economic section, location or
establishment attribute. The spatial `n >= 5` rule is not claimed as a
universal threshold for every public statistic.

## Reproducibility and remaining limitation

`renv.lock` records R 4.4.2. The public app performs no live SIRENE, BAN or IGN
request.

The complete public tree from commit
`c5ce35119c6ac92c5d2fb182da956078346c7c07` was tested in a clean
`rocker/r-ver:4.4.2` container on Linux/aarch64. All 120 lockfile package
versions were confirmed and `renv::restore()` completed successfully. All 278
public tests passed, the running application returned HTTP 200 and the offline
server start passed. The container used no host mounts and required no internal
data.

The repository can start and test the app from the four supplied aggregate
files. It does not claim an end-to-end public rebuild of those aggregates:
official source/reference holdings and reviewed internal geocoding and spatial
preparation inputs are intentionally excluded.

No suppressed residual is published for an individual grid cell. Because the
public stock aggregates include section-level aggregation-basis totals and
released spatial counts, the total threshold-excluded count can be derived for
each economic section. It cannot be assigned to particular suppressed cells
from the released spatial table.

The public repository and deployment are built only from their explicit
allowlists. Internal historical section analyses, unsafe predecessor bundles
and row-level reproduction artifacts are not allowlisted.

## Validation results

- complete local test suite: 348 passed, 0 failed, 0 warnings, 0 skipped;
- isolated public test suite: 278 passed, 0 failed, 0 warnings, 0 skipped;
- isolated Shiny application construction: passed;
- isolated construction under `en_US.UTF-8`: passed;
- isolated construction under non-UTF-8 `en_US.US-ASCII`: passed;
- public repository allowlist: 41 unique files;
- shinyapps.io deployment allowlist: 10 unique files.

The reopening chart preserves unavailable observations as gaps rather than
zeroes. In particular, 1986–1989 remain missing between the observed 1985 and
1990 values, and the segmented plot renders without ggplot warnings.

Browser checks covered the dashboard, the unchanged aggregate map, the two
annual history charts, the Top-8 creation-year figure, Methodology and Data,
About, and the narrow mobile view.
At 390 px the established fixed-width dashboard remains usable through
horizontal scrolling, but it is not a fully reflowing mobile layout.
