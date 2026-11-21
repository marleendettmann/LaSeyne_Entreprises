# Data sources, attribution and excluded material

The MIT license in this repository applies only to the original project code
and documentation. It does not replace the terms applicable to third-party
data or artwork.

## INSEE SIRENE

The public application data are derived from the official INSEE SIRENE
register. Source: Insee, API Sirene 3.11, local snapshot and analysis reference
date 17 November 2026.

Unless otherwise stated by Insee, public information, data and downloadable
files published on insee.fr are provided under the French Licence Ouverte / Open
Licence 2.0 (Etalab). Reuse requires source attribution, the data update date
when known, and must not misrepresent the information.

- SIRENE access information: <https://www.insee.fr/fr/information/3591226>
- Insee legal notice: <https://www.insee.fr/fr/information/2008466>
- Licence Ouverte 2.0: <https://www.etalab.gouv.fr/licence-ouverte-open-licence/>

The repository contains only a privacy-filtered, data-minimised derivative for
the public app. Raw API responses, SIREN/SIRET identifiers, names, full
addresses and internal validation tables are not published.

## BAN and IGN Géoplateforme

Address matching used the Base Adresse Nationale (BAN) and the official IGN
Géoplateforme geocoding service during offline preprocessing. BAN data are
available under the Licence Ouverte 2.0. Source: Base Adresse Nationale / IGN,
dated local reference used on 17 November 2026.

- BAN description and license: <https://adresse.data.gouv.fr/decouvrir-la-BAN>
- BAN terms of use: <https://adresse.data.gouv.fr/cgu>
- IGN Géoplateforme geocoding documentation: <https://cartes.gouv.fr/aide/fr/guides-utilisateur/utiliser-les-services-de-la-geoplateforme/geocodage/>

BAN extracts, geocoding queries and response caches are excluded from the
public repository. The public runtime contains no establishment coordinates.

The aggregate-map build additionally uses official IGN ADMIN EXPRESS COG
commune geometry and BD TOPO hydrographic/coastal layers, downloaded as internal
Géoplateforme extracts on 20 November 2026. They are used only to derive
deterministic land-based display anchors for coastal grid cells. The source
geometries are excluded from the repository. IGN open data are provided under
Licence Ouverte 2.0.

- IGN data and services: <https://geoservices.ign.fr/>
- Géoplateforme downloads: <https://data.geopf.fr/>

## OpenStreetMap

The running application requests its base map tiles through Leaflet. The tiles
and OpenStreetMap database are not included in this repository. The map displays
the required attribution to OpenStreetMap contributors. OpenStreetMap data are
available under the Open Database License (ODbL):
<https://www.openstreetmap.org/copyright>.

## Author logo

`www/Logo_sRGB_WEB.jpg` is the personal author logo of Marleen Dettmann. All
rights are reserved. The logo is not covered by the MIT license and may not be
reused without permission. The CMYK source artwork is retained locally and is
not part of the public repository.
