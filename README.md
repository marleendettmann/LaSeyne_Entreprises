# La Seyne Business Explorer

**Exploring business establishments in La Seyne-sur-Mer**

La Seyne Business Explorer is an interactive R/Shiny application for exploring
business establishments in La Seyne-sur-Mer, France. It combines current
establishment data, historical register information and interactive maps.

The application uses official INSEE SIRENE data as of 17 November 2026. It
builds on an earlier project by the author and was further developed with AI
assistance.

## Features

- **Interactive map:** Establishment counts aggregated into 500 m grid cells,
  with filters for 18 economic sections (NAF Rev. 2).
- **Business overview:** Key indicators for the current establishment stock.
- **Historical trends:** Annual administrative register events from 1973 to
  2026.
- **Sector comparison:** Creation years of currently active establishments
  across the eight largest economic sections (2015–2026).
- **Interactive visualizations:** Maps and charts developed with Leaflet and
  Plotly.

## Screenshots

### Dashboard and aggregate map

![Dashboard with the business-establishment map](docs/images/dashboard-map.jpg)

### Historical register charts

![Historical administrative register charts](docs/images/historical-charts.jpg)

### Methodology and geocoding-quality flow

![Methodology page with the geocoding-quality Sankey chart](docs/images/methodology-and-data.jpg)

## Data and methodology

The analysis is based on an INSEE SIRENE snapshot from 17 November 2026,
covering 14,213 active establishments in La Seyne-sur-Mer.

The map shows aggregated counts rather than individual establishment
locations. Only grid cell–sector combinations with at least five establishments
are displayed. Consequently, the map covers fewer establishments than the
statistical totals.

Historical figures reflect administrative register records and may change
following later corrections. Data for 2026 are incomplete.

The creation-year comparison includes only establishments still active on the
reference date, not all businesses created during those years.

For detailed definitions, data preparation and limitations, see
[Methodology](docs/methodology.md).

## Data sources

The application uses official data and geographic information from:

- [INSEE SIRENE](https://www.insee.fr/fr/information/3591226): Establishment
  register.
- [INSEE NAF Rev. 2](https://www.insee.fr/fr/information/2120875): Economic
  activity classification.
- [BAN](https://adresse.data.gouv.fr/decouvrir-la-BAN) and
  [IGN Géoplateforme](https://cartes.gouv.fr/aide/fr/guides-utilisateur/utiliser-les-services-de-la-geoplateforme/geocodage/):
  Address geocoding.
- [IGN](https://geoservices.ign.fr/): Administrative boundaries and land
  geometry.
- [OpenStreetMap](https://www.openstreetmap.org/copyright): Background map
  tiles.

Source attribution and licensing information are documented in
[`NOTICE.md`](NOTICE.md).

## Technical implementation

The application is built with R and Shiny, using semantic.dashboard for the
interface, leaflet for maps and plotly for interactive charts.

Package versions are recorded in [`renv.lock`](renv.lock). The public repository
includes the aggregated data required to run the application, but no original
establishment-level records or internal geocoding data.

## Installation

The application was tested with R 4.4.2.

After cloning the repository, run the following commands from the project
directory:

```r
install.packages("renv")
renv::restore()
shiny::runApp(".")
```

## Reproducibility

The application can be run and tested using the aggregated data provided in
this repository. Installation and execution have also been validated in an
isolated Docker environment.

The public test suite can be run with:

```r
testthat::test_dir("tests/testthat")
```

Recreating the underlying dataset requires additional source data and
processing steps that are not included in the public repository.

See [Release validation](docs/release-validation.md) for further details.

## Live application

[Open La Seyne Business Explorer](https://marleen-dettmann.shinyapps.io/LaSeyne_Entreprises/)

## License

The application code and documentation are available under the
[MIT License](LICENSE). Third-party data, derived datasets, map material and the
author’s logo are subject to separate terms.

See [`NOTICE.md`](NOTICE.md) for details.

## Author

**Dr. Marleen Dettmann**<br>
Demographer and data analyst<br>
[marleen-dettmann.de](https://marleen-dettmann.de/)
