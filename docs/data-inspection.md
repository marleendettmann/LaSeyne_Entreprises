# Lokale Dateninspektion

Die folgenden Beispiele werden aus dem Projektverzeichnis in R oder RStudio ausgeführt. Sie benötigen keine Netzwerkverbindung.

## Veröffentlichungsfähige App-Daten

Die laufende App verwendet ausschließlich das versionierte, aggregierte Bundle
`data/app/insee_2026-11-17_grid500_privacy_v6_simplified/`.

```r
bundle <- "data/app/insee_2026-11-17_grid500_privacy_v6_simplified"
stock <- readRDS(file.path(bundle, "stock_aggregates.rds"))
spatial <- readRDS(file.path(bundle, "spatial_aggregates.rds"))
history_yearly <- readRDS(file.path(bundle, "history_yearly.rds"))
creation_year_top8 <- readRDS(file.path(bundle, "creation_year_top8.rds"))

sum(stock$section_stock$active_count)
sum(stock$section_stock$address_exact_oo_count)
sum(spatial$count)
nrow(spatial)
length(unique(spatial$grid_id))
subset(history_yearly, year >= 2022)
stock$creation_cohorts
stopifnot(sum(stock$creation_cohorts$count) == 14213L)
stopifnot(nrow(creation_year_top8) == 96L)
stopifnot(min(creation_year_top8$count) == 13L)
```

Das Bundle enthält keine Betriebsstättenzeilen. Die räumliche Tabelle enthält
ausschließlich Zellkennung, NAF-Abschnitt, freigegebene Fallzahl und einen aus
Raster- und Landgeometrie abgeleiteten Darstellungsanker. Jede veröffentlichte
Zell-/Abschnittskombination hat mindestens fünf Fälle. SIREN/SIRET, Namen,
Adressen, Einzelkoordinaten, Detail-NAF und Rechtsformen sind nicht enthalten.
Die einzige Jahr-Branche-Tabelle enthält genau die 96 freigegebenen Werte für
die acht größten Abschnitte und 2015–2026; die vollständige interne Tabelle ist
nicht enthalten. Die sieben Erstellungszeitraum-Kohorten sind ausschließlich
gemeindeweite Aggregate.

Eine zusätzliche Schema- und Datenschutzprüfung ist möglich mit:

```r
source("R/app_runtime.R")
check <- validate_public_runtime_data(
  stock, spatial, history_yearly, creation_year_top8
)
stopifnot(check$valid)
```

## Interne Zwischenprodukte aus öffentlich zugänglichen Ausgangsdaten

Die amtlichen SIRENE-Ausgangsdaten sind öffentlich über INSEE zugänglich. Die
daraus lokal erzeugten Betriebsstätten-Dateien sind dennoch interne,
zeilenbezogene Arbeitsstände und weder Bestandteil des öffentlichen Repositorys
noch des Deployments. Sie können ausschließlich im vollständigen lokalen
Entwicklungsprojekt geprüft werden:

```r
public_establishments <- readRDS(
  "data/processed/insee_sirene_20261117103727/public-app/public_app_establishments_2026-11-17.rds"
)
public_history <- readRDS(
  "data/processed/insee_sirene_20261117103727/public-app/public_app_history_yearly_2026-11-17.rds"
)

stopifnot(nrow(public_establishments) == 14213L)
stopifnot(sum(public_establishments$geocoding_quality == "address_exact") == 5214L)
stopifnot(all(is.na(public_establishments$longitude[
  public_establishments$geocoding_quality != "address_exact"
])))
```

Diese zeilenbezogenen Dateien bleiben unveränderte interne Zwischenprodukte.
Das öffentliche App-Bundle ist eine davon getrennte, versionierte Aggregation
ohne Betriebsstätten-Einzelzeilen.

## Interne Validierungs- und Rohdaten

Die folgenden Verzeichnisse sind ausschließlich für lokale Reproduktion, Qualitätskontrolle und methodische Prüfung bestimmt:

- `data/raw/insee_sirene_20261117103727/`: originale API-Antworten und interner Geokodierungscache;
- `data/processed/insee_sirene_20261117103727/establishment_current_2026-11-17.rds`: validierter interner Betriebsstättenbestand mit SIRET/SIREN und Diffusionsstatus;
- `data/processed/insee_sirene_20261117103727/activity/`: interne amtliche NAF-Zuordnung;
- `data/processed/insee_sirene_20261117103727/history/`: Perioden und Ereignisse auf Betriebsstättenebene;
- `data/reference/ban_2026-11-17/`: lokaler BAN-Referenzbestand.

Beispiel einer ausschließlich internen Strukturprüfung:

```r
internal_current <- readRDS(
  "data/processed/insee_sirene_20261117103727/establishment_current_2026-11-17.rds"
)

names(internal_current)
table(
  internal_current$diffusion_status,
  internal_current$legal_unit_diffusion_status,
  useNA = "ifany"
)
```

Interne Dateien dürfen nicht in ein öffentliches Deployment kopiert oder von der Shiny-App geladen werden. Insbesondere dürfen SIREN/SIRET, Namen, Adressen, Rohabfragen und Koordinaten eingeschränkt diffundierter Einheiten nicht veröffentlicht werden.

## Interne Erzeugung des App-Bundles

`scripts/prepare_simplified_public_bundle.R` erzeugt aus dem nicht
veröffentlichten, intern validierten Vorgängerbundle und dem validierten
aktuellen Bestand das vereinfachte Bundle
mit gemeindeweiten Kohorten und der geprüften Top-8-Tabelle. Die vorgelagerte
räumliche Aufbereitung und vollständige Jahr-Branche-Ableitung bleiben ein
interner, nicht veröffentlichter Reproduktionsschritt. Das öffentliche Skript
stellt keine API-Anfragen und verweigert das Überschreiben eines vorhandenen
Bundles. Es ist deshalb kein eigenständig ausführbarer End-to-End-Aufbau aus
einem öffentlichen Repository-Klon. Der öffentliche Klon ist für App-Start und
Validierung der mitgelieferten Aggregate vollständig; die vollständige
Datenaufbereitung benötigt zusätzlich bewusst nicht veröffentlichte Ausgangs-
und Referenzdaten.

Für eine spätere Aktualisierung ist ein neues datiertes Zielverzeichnis anzulegen und anschließend `app_bundle_dir` in `global.R` bewusst auf diese geprüfte Version umzustellen.
