# SIRENE current-stock methodology

## Scope

This project analyses establishments (`établissements`) located in La
Seyne-sur-Mer (`codeCommuneEtablissement = 83126`). The current pipeline uses
the official INSEE API Sirene 3.11 and does not yet produce historical opening
or closure event series.

The workflow distinguishes:

- `retrieved_at`: when this project called the API;
- `snapshot_date`: the date of the latest availability for the official
  `Établissements` collection returned by `/informations`;
- `analysis_date`: the explicit date for which the project reconstructs a
  current establishment status;
- `dateCreationEtablissement`: the registered creation date;
- period `dateDebut` and `dateFin`: effective boundaries of one register period.

## Documented INSEE semantics

The following statements come from INSEE documentation:

- `dateCreationEtablissement` is the establishment creation date. Except for
  purged legal units, an unknown value can be represented by `1900-01-01`;
  purged records can instead contain a missing value.
- A SIRENE history period is an interval during which the historized variables
  remain unchanged. `dateDebut` and `dateFin` are effective period boundaries.
- The earliest period boundary does not necessarily equal the establishment
  creation date and can predate it. It must not be used as a creation date.
- `etatAdministratifEtablissement` is `A` (active) or `F` (closed). A closed
  establishment can later reopen.
- `nombrePeriodesEtablissement` reports the number of establishment periods.
- The API `date` query parameter applies search criteria on historized fields at
  the supplied date. It does not state that returned history arrays are trimmed
  to that date.
- INSEE recommends starting cursor downloads after the daily update and warns
  that a change to `dateDerniereMiseADisposition` during pagination can create
  inconsistent pages.

Official sources:

- <https://www.insee.fr/fr/information/3591226>
- <https://www.insee.fr/fr/statistiques/fichier/3711695/Description-liste-sirene-fr.pdf>
- <https://portail-api.insee.fr/>
- <https://www.insee.fr/fr/information/9053325>
- <https://www.data.gouv.fr/datasets/base-sirene-des-entreprises-et-de-leurs-etablissements-siren-siret>

## Empirically observed API behaviour

The controlled API page retrieved on 17 November 2026 contained five records
with an open-ended period beginning after the official collection availability
date. Four also had a future `dateCreationEtablissement` and no earlier period.
The fifth already existed and had a preceding period covering the analysis
date. Its future period began after that preceding period ended.

An authenticated search using `date=2026-11-17` still returned the complete
period array, including the future period. The project therefore does not treat
the API `date` parameter as a substitute for explicit period selection.

The reviewed INSEE documentation does not provide a separate general rule for
future effective periods. Their presence is treated as observed API behaviour,
not as a documented error or as proof of current activity.

## Methodological rules used by the pipeline

A period is applicable at `analysis_date` when:

```text
dateDebut <= analysis_date
and (dateFin is missing or dateFin >= analysis_date)
```

This inclusive interval rule matches the observed contiguous period sequences,
where one period ends on the day before the next begins.

For each SIRET:

1. If `dateCreationEtablissement > analysis_date`, `future_creation` is true.
   The record remains in the internal snapshot but has no status at the analysis
   date and is excluded from counts of establishments already in existence.
2. `future_period` is true when at least one returned period begins after the
   analysis date.
3. For an establishment already created, exactly one applicable period is
   required to derive `status_at_analysis_date`.
4. If zero or multiple periods apply, the status is left missing and
   `status_unresolved` is true. No fallback to the open-ended API period is made.
5. `administrative_status` retains the status of the API's open-ended period.
   It is deliberately distinct from `status_at_analysis_date`.
6. One narrow current-stock exception applies to purged legal units. INSEE can
   return one closed, open-ended period with both creation date and `dateDebut`
   unknown. When `analysis_date` exactly equals `snapshot_date`, the current API
   status is used and its source is recorded as
   `api_current_purged_missing_start`. The same record remains unresolved for
   every earlier analysis date because its closure start is unknown.

These rules reconstruct a register status. They do not prove economic activity.
They also do not define creation or closure events from arbitrary period starts.
A defensible event history must inspect status changes, reopenings and, where
relevant, establishment succession links in a separate historical workflow.

## Remaining limitations

- SIRENE changes can be registered retrospectively. A later API response can
  therefore alter periods that cover an earlier analysis date. This pipeline
  reconstructs the status from the response available at retrieval time; it is
  not an immutable historical vintage.
- Future effective periods are present in the API, but the reviewed official
  sources do not specify every operational reason for them.
- `1900-01-01` can mean an undetermined creation date and must not be interpreted
  as an observed creation on that date.
- Gaps in period coverage remain unresolved rather than being imputed.
- The current municipal query uses the address currently returned for a SIRET.
  It does not by itself reconstruct every historical location change.
- Historical opening and closure counts are outside this current-stock snapshot
  and require a separately validated event model.
- The current-stock fallback for purged establishments supports only the API
  snapshot date. It must never be used to infer a historical closure date.

# Historical status-transition methodology

## Population and interpretation

The phase 2D.1 history is a retrospective reconstruction for the 44,365 SIRET
returned by the **current** municipal snapshot query for La Seyne-sur-Mer. It is
not a historical register of every establishment that was ever located in the
municipality: establishments no longer returned under the current address
criterion can be absent, while earlier periods can refer to times before a
location or other attribute changed. The results must therefore not be labelled
as official business births, deaths or local business-demography statistics.

## Source fields and period completeness

The workflow retains every `periodesEtablissement` item from the immutable local
API JSON and verifies its count against `nombrePeriodesEtablissement`. The
chronological `period_number` in the processed table is derived by this project;
the API response does not supply a period sequence number. The fields used are:

- `dateCreationEtablissement` for administrative creation cohorts;
- period `dateDebut` and `dateFin` for effective interval boundaries;
- period `etatAdministratifEtablissement` for A/F state;
- `changementEtatAdministratifEtablissement` as a consistency check;
- `unitePurgeeUniteLegale` to identify purged legal-unit records.

For the 17 November 2026 batch, all declared period counts match the returned
arrays. Adjacent dated periods are contiguous: a period ends one day before the
next begins. This is an empirical validation of this batch, not a general
licence to repair future gaps or overlaps.

## Event definitions

Periods are sorted by effective start date for each SIRET. A transition is
accepted only when both neighbouring statuses are A or F, their boundaries are
contiguous, and the API change indicator agrees with whether the status changed.
The start of the later period is then the effective event date:

- A → F: administrative closure;
- F → A: administrative reopening;
- A → A or F → F: another register-period change without status change;
- missing/invalid status, non-contiguous boundary, overlap, duplicate, or an
  inconsistent change indicator: unresolved transition.

The first known period is not itself treated as an event. In particular, its
`dateDebut` is never substituted for the creation date. Multiple closures and
reopenings for one SIRET remain separate events. Periods beginning after the
analysis date remain in `establishment_periods` but their transitions are
excluded from the historical event table.

Administrative creation is counted only when `dateCreationEtablissement` is
present, differs from the documented unknown-value placeholder `1900-01-01`,
and is on or before the analysis date. Missing, placeholder and future dates are
reported separately and are not imputed.

## Annual series and limitations

The annual index begins in 1973, the year the SIRENE register was established,
and ends at the analysis year. Earlier creation dates are retained in the cohort
table but are outside the principal series because they describe establishments
that predate the register. No year is marked complete: the population is
conditioned on inclusion in the 2026 municipal snapshot, historical changes can
be registered retrospectively, purged histories can lack dates, and the query
does not reconstruct former municipal locations. Empty cells are consequently
left missing rather than filled with zero. The year 2026 is additionally marked
as a partial calendar year through 17 November 2026.

These reconstructed administrative transitions differ from official INSEE
enterprise-demography definitions, which use dedicated statistical populations,
continuity and reactivation rules. A SIRENE A→F transition is not by itself
proof of economic cessation, and an F→A transition is not a newly created
establishment.

# Activity classification and geocoding preparation

## Version-dependent activity classification

The active stock at 17 November 2026 is classified using the official INSEE NAF
rév. 2 files: the five nested levels, official titles and section labels. The
join key is the pair `nomenclatureActivitePrincipaleEtablissement` plus
`activitePrincipaleEtablissement`; labels are never inferred from free text. The
processed table retains the original APE code and nomenclature version together
with the official subclass title, section code and section title.

Official reference pages and source files:

- NAF rév. 2 downloads: <https://www.insee.fr/fr/information/2120875>
- NAF 2025 structure and October 2026 correspondence tables:
  <https://www.insee.fr/fr/information/8617910>
- historical NAF correspondence information:
  <https://www.insee.fr/fr/information/2579599>

NAF rév. 2 remains the APE reference through 31 December 2026. NAF 2025 becomes
the reference on 1 January 2027. Its October 2026 structure, titles and NAF rév.
2 correspondence table are stored locally as versioned official source files.
The correspondence contains both unique and multiple relations, so this phase
does not replace a 2026 NAF rév. 2 code with one arbitrarily selected NAF 2025
code.

All 14,213 establishments active at the analysis date have a NAF rév. 2 code and
all map to one of the 732 official subclasses. Historical API periods contain
62,382 NAF rév. 2, 14,113 NAF 1993, 8,373 NAF rév. 1 and 2,967 NAP values; 10,414
periods have no activity nomenclature value. Direct time comparisons within one
version are possible. Comparisons across versions require a separately specified
harmonisation target and explicit treatment of one-to-many and many-to-one
correspondences. No such comprehensive harmonisation is performed here.

## Geocoding source and quality rules

The recommended source is the IGN Géoplateforme geocoding service with its BAN
address index: <https://cartes.gouv.fr/aide/fr/guides-utilisateur/utiliser-les-services-de-la-geoplateforme/geocodage/>.
It is the official successor to the deprecated `api-adresse.data.gouv.fr`
endpoint. The address index is refreshed weekly from the Base Adresse Nationale,
the service supports single and batch requests, and the documented public limit
is 50 requests per IP per second. BAN data are available under the Licence
Ouverte with source attribution: <https://adresse.data.gouv.fr/decouvrir-la-BAN>.
A local workflow is also possible using the official daily/weekly BAN downloads;
this is preferable for reproducible full refreshes because it can pin an input
file and avoid service variability.

The controlled test used only 20 active establishments for which both the
establishment and legal unit have diffusion status `O`. It sent address
components only, never names. A result is accepted as an exact candidate only
when the service returns HTTP 200, commune code `83126`, type `housenumber`, a
score of at least 0.80 and plausible coordinates. Street/locality matches are
approximate and must not be displayed as exact establishment points. Missing,
low-score, multiple or out-of-commune results require review or remain missing.
The score threshold is a project quality rule, not an official IGN guarantee.

The test returned HTTP 200 for all 20 requests, a result for 19, plausible local
coordinates for 19, seven exact candidates under the strict rule, twelve
low-score/non-exact results, one missing result and one query with more than one
candidate. This supports Géoplateforme/BAN as the source, but not automatic
publication without result-level validation.

## Privacy and public-snapshot boundary

Exact coordinates are eligible only when both
`statutDiffusionEtablissement = O` and `statutDiffusionUniteLegale = O`. Any `P`
at either level prohibits an exact public point. `[ND]` and
`[NON DIFFUSIBLE]` values are converted to missing during address preparation
and are never copied into a public artifact. Names, SIRET/SIREN, full addresses,
person identifiers and raw geocoding queries are excluded from the proposed
public application schema.

This earlier design stage produced an internal establishment-level candidate
only. It is not part of the current public runtime. The released application
uses aggregate stock, spatial and annual-history tables; internal validation
data and geocoding results remain separate and unpublished.

# Phase 2D.4 public geocoding snapshot

## Fixed inputs

The population, analysis status and diffusion fields come exclusively from the
validated `establishment_current_2026-11-17.rds` snapshot. Official section
codes and labels come from the validated NAF rév. 2 classification. Because the
validated RDS intentionally contains no addresses, address components and
`identifiantAdresseEtablissement` are re-read only from the immutable original
JSON pages of the same SIRENE batch. They do not redefine population or status.

The local address reference is the official BAN Var CSV retrieved on 17
November 2026. Its HTTP `Last-Modified` value is 17 November 2026 01:50:18 UTC,
and the compressed input is fixed by SHA-256. It contains 9,850 unique normalized
address keys for commune 83126.

## SIRENE identifiers and local BAN join

Among the 11,858 O/O establishments, 11,278 SIRENE address identifiers are
present and 580 are missing. They represent 865 distinct register address
groups: 203 occur once and 662 occur more than once. None directly matches the
current BAN `id` format, so they are not treated as current BAN primary keys.

The first stage joins a normalized key of street number, repetition index,
street name, postcode and commune code. Local BAN keys must be unique. Repeated
establishments sharing one address remain separate rows. BAN positions marked
as entrance, building, staircase or postal delivery are `address_exact`; less
precise BAN position types are `address_approximate`.

## Géoplateforme completion and quality classes

Only public O/O addresses not matched locally and having a street value are
deduplicated and sent to the IGN Géoplateforme BAN address index. The run used
2,872 unique queries at no more than 20 requests per second. Responses are
cached internally with status, candidate count, score, type, commune and
coordinates. All final cached responses returned HTTP 200; 1,110 queries had
more than one candidate.

- `address_exact`: exact local BAN position, or a house-number candidate with
  score at least 0.80, commune 83126, plausible coordinates and either one
  candidate or a lead of at least 0.10 over the second candidate;
- `address_approximate`: house-number candidate failing the exact rule;
- `street_only`: best result is a street, locality or municipality;
- `unmatched`: no usable result or no geocodable public street;
- `restricted`: at least one diffusion level is not `O`; no request is made.

Only `address_exact` retains coordinates publicly. All other classes have
missing public coordinates. No jitter or artificial displacement is applied.

## Validated result and privacy review

The 14,213 active rows split into 5,214 `address_exact`, 2,703
`address_approximate`, 3,222 `street_only`, 719 `unmatched` and 2,355
`restricted`. The 5,214 exact O/O rows are an internal aggregation basis only;
no establishment row or individual coordinate is part of the public runtime.

The current public stock object contains section-level totals, seven
municipality-wide creation-period cohorts and four geocoding-flow totals. It
contains no creation-year/section table. The spatial object contains only a
synthetic grid identifier, NAF section, released count and deterministic display
anchor. It excludes SIREN, SIRET, names, addresses, raw queries, establishment
coordinates, detailed NAF, creation year, legal form and person type. Annual
history remains a separate aggregate table with its existing completeness flags.

# Earlier less-precise geocoding experiment

The optional map layer starts from the 5,925 public O/O establishments classified
as `address_approximate` or `street_only`. Coordinates are grouped after rounding
to seven decimal places and their normalized original street labels are compared.
When one coordinate represents more than one distinct original street, every row
at that coordinate is excluded from the spatial layer. This removes 2,727 rows.
It does not remove establishments from stock totals, activity totals or historical
statistics. Shared coordinates are retained when they represent one original
street, including genuinely shared full addresses and street-level approximations.

The remaining 3,198 candidates all fall inside the existing commune-constrained
plausibility envelope; no further location exclusion is required. They are
projected to Lambert-93 (`EPSG:2154`) and aggregated to a fixed 500 metre square
grid. Aggregation is performed separately by official NAF section. A cell/section
combination is published only at a count of at least three. This leaves 2,595
displayed establishments in 361 cell/section rows and 71 distinct cells; 603
candidates are suppressed by the minimum-count rule.

The resulting grid remains an internal, reproducible development artefact. It
is not loaded by the current public app and is not used by the privacy aggregate
map described below.

# Privacy aggregate public map (Variant C)

The spatial component now distributed in
`grid500_privacy_v6_simplified` preserves the validated aggregate values first
established for Variant C and replaces all public establishment rows with
aggregates. The spatial basis is restricted to the
5,214 address-exact establishments whose establishment and legal-unit diffusion
statuses are both `O`. Points are projected to Lambert-93 (`EPSG:2154`) and
assigned to the established fixed 500 metre grid. Aggregation is by grid cell
and official NAF rév. 2 section.

A cell/section combination is released only when `n >= 5`. No uncut cell total,
suppressed residual or complementary subtotal is published. The all-sections
view is calculated solely by summing released cell/section combinations, so it
cannot disclose suppressed components by subtraction. This produces 286
released combinations in 51 cells, representing 4,272 establishments; 942 of
the address-exact basis are excluded by the threshold. Sections A, D, E and O
have no released spatial combination and therefore display an explanatory empty
state while their full statistical totals remain available.

Circles are drawn at deterministic anchors and their area is proportional to
the released count. The circles represent aggregate grid values, not exact
locations. The anchor is the geometric grid centre when it lies on validated
land. For three coastal cells whose centre lies over water, the anchor is
`st_point_on_surface(st_intersection(grid_cell, land_geometry))`. It is derived
only from grid and land geometry, never from establishment coordinates.

At close zoom (zoom level 15 or higher), the public map adds a very transparent
fill and fine outline for only the released cells in the current selection.
The complete internal grid and suppressed cells are not drawn. A cell click
repeats only the same released section and count already available from its
proportional circle. Section changes use `leafletProxy()` and retain the current
viewport; the home control explicitly restores the fixed overview.

## Official land geometry and coastal validation

The internal build uses official IGN Géoplateforme extracts downloaded on
20 November 2026:

- ADMIN EXPRESS COG commune geometry for code 83126 (`COMMUNE`), Lambert-93;
- BD TOPO `SURFACE_HYDROGRAPHIQUE`, Lambert-93, to remove marine and harbour
  water from the commune geometry;
- BD TOPO `LIMITE_TERRE_MER` as a coastal reference check.

The sources are live IGN Géoplateforme extracts retrieved on 20 November 2026;
the responses do not carry a separate versioned archive date. They are IGN open
data under Licence Ouverte 2.0 and use RGF93 / Lambert-93 (`EPSG:2154`). The
local SHA-256 checksums are:

- commune 83126: `896bd3e24a5887bc80de2c8a402b4ac713d0cb62a6aad6a782546f87eb7409e5`;
- commune bbox extract: `8bfe856369dd6af419ca23d52858c62e379249e14c35a54239f994f545667819`;
- hydrographic surfaces: `31b273ae5f87595e42a620101d185382f513fceb550c8c4f3c3af39dda1db35e`;
- land/sea limit: `7019ead8437e7b6bd4060ee4726e596c62396fe36c7c7d87f2c3ac8f245386e7`.

The official source catalogue and licensing links are recorded in `NOTICE.md`;
source files remain internal and ignored by Git. Of the 51 released cells, 48 centres
lie on land and three require land-derived anchors. Those three cells account
for 18 released cell/section combinations and 706 represented establishments.
Anchor shifts are approximately 129.2, 174.3 and 206.7 metres.

## Coverage flow and final public runtime

The Methodology & Data Sankey distinguishes the complete active stock (14,213),
the address-exact O/O internal basis (5,214), released spatial aggregates
(4,272), threshold-excluded exact records (942), less-precise geocoding (5,925),
unmatched records (719) and restricted diffusion (2,355).

The public runtime bundle `insee_2026-11-17_grid500_privacy_v6_simplified`
loads only `stock_aggregates.rds`, `spatial_aggregates.rds` and the
byte-identical unchanged `history_yearly.rds`. It does not load establishment rows,
grid polygons, IGN source geometry, internal bundle metadata or geocoding
caches, and it does not require `sf` or `jsonlite` at startup. The navigation
remains Dashboard, Methodology & Data, and About.

Shiny automatically loads only the public schema and display helpers in
`R/app_runtime.R`. Internal row-level validation, classification and historical
reconstruction helpers are kept outside `R/` and are never autoloaded by the
app. The same runtime file is explicitly present in the
deployment allowlist, preventing local and isolated starts from using different
function definitions.

# Simplified public historical statistics

The original annual total-register series for 1973–2026 is retained unchanged.
No historical economic-section table, interval filter or geographic breakdown
is published. The annual figures are municipality-wide retrospective register
reconstructions rather than official business-demography births and deaths. The
incomplete 2026 calendar year covers 1 January through 17 November.

Seventeen early annual closure or reopening values are positive and below five.
They are retained because the complete annual series contains no economic
section, spatial location or establishment attribute. On that coarse
municipality-wide level the analytical value of an uninterrupted series
outweighs the limited disclosure signal. Consequently, the spatial `n >= 5`
rule is not described as a universal publication threshold.

The current active stock is also summarised in seven municipality-wide creation
periods: unknown or undetermined, before 2000, 2000–2009, 2010–2014, 2015–2019,
2020–2024 and 2025–2026. These counts sum to 14,213 and cannot be filtered or
cross-tabulated by economic section, grid cell, geocoding quality, legal form or
another establishment characteristic. The SIRENE placeholder `1900-01-01` is
assigned to the unknown or undetermined category and is never interpreted as an
actual creation date.
