# Official SIRENE import workflow

Phase 2C.1 adds a separate, explicit workflow. It does not feed the existing
Shiny application yet.

## Source decision

The workflow uses the official INSEE API Sirene 3.11. It is restricted to
establishments whose official commune code is `83126`. This avoids downloading
the national current and historical stock files. Version 3.11 is the current
stable API; an experimental API version is not required.

The API requires an integration key. Create an application on
<https://portail-api.insee.fr/>, subscribe it to API Sirene 3.11, and provide
the key to R through the environment:

```sh
export INSEE_API_KEY="..."
```

Never add the key to a script or commit `.Renviron`. The project `.gitignore`
excludes `.Renviron`, `data/raw/`, and `data/processed/`.

## Controlled test download

The following command downloads only one API page and marks the resulting
batch as incomplete:

```sh
Rscript scripts/download_data.R --max-pages=1
```

Incomplete batches cannot be processed. The key is transmitted in the
`X-INSEE-Api-Key-Integration` header and is not written to logs or manifests.
The partial manifest records the downloaded byte count and extrapolates an
estimated size for the complete municipality result.

## Complete municipality download

After reviewing the one-page test, download the full municipality result:

```sh
Rscript scripts/download_data.R
```

The query is `codeCommuneEtablissement:83126`, with cursor pagination and up to
1,000 establishments per page. Phase 2B observed about 44,000 current register
rows through OpenDataSoft, so approximately 45 API pages are expected. The
official JSON payload size has not yet been measured because no authenticated
request was available during phase 2C.1; run the controlled first-page test
before the complete download.

Each run receives a new timestamped directory under `data/raw/`. Existing
downloads are never overwritten. The raw JSON preserves the original API
variables and may contain personal or protected register information; it must
remain local.

## Preparation

Pass one completed download directory explicitly:

```sh
Rscript scripts/prepare_data.R \
  --input=data/raw/insee_sirene_YYYYMMDDHHMMSS \
  --analysis-date=YYYY-MM-DD
```

The script retains the API's single open-ended period and separately derives the
status applicable at the explicit analysis date from all returned periods. It creates
an internal `establishment_current_YYYY-MM-DD.rds` snapshot under
`data/processed/`. Validation runs before the output is finalized. Existing
snapshots are never overwritten. If metadata writing fails after the snapshot
rename, the new snapshot is removed.

The normalized table contains SIRET, SIREN, commune, status, headquarters and
diffusion indicators, creation and current-period dates, activity code and
nomenclature, and the official snapshot date. The official Sirene API does not
provide map coordinates. Coordinates therefore remain missing. Sector labels
also remain missing until an official nomenclature table is joined in a later
phase.

Metadata record the source, query, retrieval and snapshot dates, record counts,
status and missing-value summaries, validation messages, and a SHA-256 checksum
of the RDS file.

Future creation and period dates are retained. A future creation has no status
at the analysis date. For an existing establishment, exactly one period must
cover the analysis date; otherwise the status remains unresolved. See
[`methodology.md`](methodology.md) for definitions and limitations.

## Privacy boundary

Raw API pages and the prepared internal snapshot are local processing data.
Phase 2C.1 does not create a public application snapshot. Names and addresses
are not copied into `establishment_current`, but SIRET and any future exact
coordinates still require a separate publication decision. Coordinates must
not be published for records where the establishment or legal unit has partial
diffusion status.

## Tests

Tests use synthetic establishments only:

```sh
Rscript tests/testthat.R
```

They cover required fields, SIRET uniqueness and structure, SIREN linkage,
status values, commune filtering, date logic, coordinate validity, diffusion
status, and activity nomenclatures.

## Historical analysis

This phase processes only the current establishment period. A defensible
closure history requires the official historized establishment stock and,
where relevant, establishment succession links. That work is deferred to phase
2C.2.
## Phase 2D.2/2D.3 reference and geocoding inputs

Official activity reference files are stored unchanged below
`data/reference/insee_naf/`. The directory contains NAF rév. 2 nested levels,
titles and sections plus the October 2026 NAF 2025 structure, titles and
NAF-rév.-2-to-NAF-2025 correspondence file. Their origin and version must be
reviewed before a later refresh; reference files are never silently replaced.

With the separately obtained official reference files and the internal current
snapshot, the active-stock classification can be run with:

```sh
Rscript scripts/prepare_activity_classification.R \
  --current=data/processed/insee_sirene_20261117103727/establishment_current_2026-11-17.rds \
  --reference-dir=data/reference/insee_naf \
  --analysis-date=2026-11-17 \
  --output-dir=data/processed/insee_sirene_20261117103727/activity
```

The script refuses to overwrite existing artifacts and validates the 732-entry
NAF rév. 2 reference, unique version/code keys, active-stock row count and the
sum of mapped/unmapped categories.

The following controlled geocoding command documents an internal development
step. Its script and row-level inputs are intentionally not part of the public
release candidate:

```sh
Rscript scripts/geocode_controlled_sample.R \
  --raw-dir=data/raw/insee_sirene_20261117103727 \
  --current=data/processed/insee_sirene_20261117103727/establishment_current_2026-11-17.rds \
  --analysis-date=2026-11-17 \
  --sample-size=20 \
  --output-dir=data/processed/insee_sirene_20261117103727/geocoding-test
```

This command performs external requests and must remain a deliberately invoked
validation step. It selects only active O/O records with numbered addresses,
uses commune code `83126`, throttles requests below the documented public limit,
and writes a new internal test artifact. It does not create a public snapshot.
For a future full refresh, prefer a dated local BAN extract or the official
batch endpoint, persist source date/checksum, and require explicit approval
before processing all eligible addresses.

## Phase 2D.4 full public-snapshot build (internal)

This section documents the internal build provenance; it is not an instruction
that can be executed from the public repository alone. The departmental BAN
file is fixed locally as
`data/reference/ban_2026-11-17/adresses-83.csv.gz`. The rolling BAN URL was used
only after checking file size and HTTP `Last-Modified`; metadata and SHA-256 pin
the retrieved input.

```sh
Rscript scripts/prepare_public_snapshot.R \
  --current=data/processed/insee_sirene_20261117103727/establishment_current_2026-11-17.rds \
  --classification=data/processed/insee_sirene_20261117103727/activity/active_establishment_activity_2026-11-17.rds \
  --raw-dir=data/raw/insee_sirene_20261117103727 \
  --ban=data/reference/ban_2026-11-17/adresses-83.csv.gz \
  --history=data/processed/insee_sirene_20261117103727/history/establishment_yearly_2026-11-17.rds \
  --analysis-date=2026-11-17 \
  --rate-per-second=20 \
  --cache-dir=data/raw/insee_sirene_20261117103727/geocoding_phase2d4 \
  --output-dir=data/processed/insee_sirene_20261117103727/public-app
```

The internal query cache makes retries resumable and avoids repeated requests
for shared addresses. Network timeouts and 429/5xx responses use bounded
retries. The script refuses to overwrite outputs, validates all 14,213 active
rows and section assignments, and finalizes establishment, annual-history and
metadata files only after all checks pass.
