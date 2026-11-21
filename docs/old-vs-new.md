# Alt-Neu-Vergleich der Shiny-App

Vergleichsstand: 17.11.2026

## Zusammenfassung

Die bisherige App verwendete bei jedem Start `dataseed-sirene_mde.csv`. Die neue lokale Version lädt ausschließlich das versionierte öffentliche App-Bundle unter `data/app/insee_2026-11-17_grid500_privacy_v6_simplified/`. Es übernimmt die validierten räumlichen Aggregate unverändert und enthält nur gemeindeweite historische Jahreswerte sowie gemeindeweite Erstellungszeitraum-Kohorten. Die App führt beim Start keine INSEE-, BAN- oder IGN-Anfragen aus. Die ursprüngliche CSV bleibt unverändert erhalten.

## Bestandskennzahlen

| Kennzahl | Bisherige App | Neue App | Ursache |
|---|---:|---:|---|
| Angezeigter aktiver Bestand | 11.454 | 14.213 | vor allem neuer Datenstand; zusätzlich offizielle, stichtagsbezogene INSEE-Aufbereitung statt ODS-Feldern und CSV-Filter |
| Einzelne Kartenmarker | 11.454 | 0 | methodische Änderung: keine Betriebsstättenpunkte werden veröffentlicht |
| Räumlich repräsentierte Betriebe | nicht aggregiert | 4.272 | 286 freigegebene Zell-/Abschnittskombinationen mit `n >= 5` |
| Approximative Geokodierungen | nicht getrennt ausgewiesen | 2.703 | neue Qualitätsklassifikation |
| Straßengenaue Geokodierungen | nicht getrennt ausgewiesen | 3.222 | neue Qualitätsklassifikation |
| Eingeschränkt diffundierte Betriebe | nicht als eigene Kartenregel dokumentiert | 2.355, ohne räumliche Darstellung | neue Datenschutzregel auf Betriebsstätten- und Rechtseinheitenebene |

Die Differenz von 2.759 aktiven Betriebsstätten darf nicht als reines Wirtschaftswachstum interpretiert werden. Die alte Datei enthält Registerangaben bis Anfang 2023, besitzt aber keinen eindeutig dokumentierten Analysestichtag. Die neue Zahl ist der validierte Bestand am 17.11.2026 für Gemeindecode 83126.

## Datenstandsänderungen

- Alt: OpenDataSoft-Export mit Daten bis Anfang 2023; Filter `etatadminis == "Actif"` und fehlendes `yearfermetu`.
- Neu: offizieller INSEE-SIRENE-Snapshot, Analyse- und Datenstand 17.11.2026, stichtagsbezogene Statusauswertung.
- Alt: Branchenfelder aus der aufbereiteten ODS-Datei.
- Neu: amtliche NAF-rév.-2-Zuordnung mit vollständig validierten Wirtschaftsabschnitten für alle 14.213 aktiven Betriebsstätten.

Diese Änderungen betreffen den beobachteten Datenstand. Sie sind von den nachfolgenden methodischen Änderungen zu unterscheiden.

## Methodische Änderungen

### Karte

Die alte App behandelte alle 11.454 Koordinaten als gleichwertige Einzelstandorte. Die neue App unterscheidet intern:

- 5.214 adressgenaue O/O-Betriebsstätten als Aggregationsbasis, nicht als Einzelmarker;
- 5.925 O/O-Betriebsstätten mit approximativer oder straßenbezogener Position, die nicht als öffentliche Einzelstandorte dargestellt werden;
- 719 nicht geokodierbare sowie 2.355 eingeschränkt diffundierte Betriebsstätten ohne räumliche Darstellung.

Die öffentliche Karte aggregiert ausschließlich die 5.214 adressgenauen O/O-Fälle
in einem festen 500-m-Raster nach Wirtschaftsabschnitt. Veröffentlicht werden
nur Kombinationen mit mindestens fünf Fällen: 286 Zell-/Abschnittskombinationen
in 51 Zellen repräsentieren 4.272 Betriebe. Die Gesamtansicht summiert nur diese
freigegebenen Komponenten. Weniger präzise, nicht geokodierte und eingeschränkt
diffundierte Fälle bleiben ausschließlich in den statistischen Kennzahlen.

### Zeitreihen

Die alte App leitete „Registrations“ und „Closures“ aus `yearcreatio` und `yearfermetu` der ODS-Datei ab. Für 2022 ergaben sich 1.367 Erstellungen und 795 Schließungen.

Die neue App verwendet die validierte öffentliche Jahrestabelle. Für 2022 enthält sie 1.777 administrative Erstellungen, 1.336 administrative Schließungen und 99 Wiedereröffnungen. Die Unterschiede entstehen sowohl durch den späteren Datenstand als auch durch die methodisch explizite Auswertung von Registerperioden und Statusübergängen.

`dateDebut` wird nicht als Gründungsdatum interpretiert. Administrative Erstellungen beruhen auf `dateCreationEtablissement`; Schließungen auf einem Übergang von aktiv zu geschlossen und Wiedereröffnungen auf einem Übergang von geschlossen zu aktiv. Gleichartige oder unklare Periodenänderungen werden nicht stillschweigend als Eröffnung oder Schließung umgedeutet.

Die historische Tabelle ist eine retrospektive Rekonstruktion aus dem aktuellen Registersnapshot. `coverage_complete` ist deshalb für die historischen Jahre `FALSE`. Rückwirkende Registeränderungen und bereinigte Historien können spätere Snapshot-Ergebnisse verändern. Das Jahr 2026 ist außerdem nur bis zum Analysestichtag 17.11.2026 vollständig; die Kennzahlenboxen zeigen deshalb 2025 als letztes vollständiges Kalenderjahr.

### Diagramme

- Das Flächendiagramm bleibt bestehen und kann zwischen administrativen Erstellungen, Schließungen und Wiedereröffnungen wechseln.
- Das Jahresbalkendiagramm zeigt nun die drei methodisch getrennten Registerereignisse statt eines aktuellen Aktiv/geschlossen-Status nach Erstellungsjahr.
- Das frühere Jahr-Branche-Diagramm wurde durch sieben gemeindeweite Erstellungszeitraum-Kohorten des am 17.11.2026 aktiven Bestands ersetzt. Geschlossene Betriebsstätten sind darin nicht enthalten; der Wert 1900 wird als unbekannt oder nicht bestimmbar behandelt.

## Unveränderte Bedienlogik

Die semantic.dashboard-Navigation, Kennzahlenboxen, Leaflet-Karte,
Die Branchenauswahl der Karte und die Radioauswahl der jährlichen Gesamtzeitreihe bleiben erhalten. Historische Branchenfilter und der Jahresslider des früheren Jahr-Branche-Diagramms wurden aus Datenschutzgründen entfernt.
Die finale Navigation trennt Dashboard, Methodology and Data und About. Die Karte
zeigt proportionale Kreise an festen Rasterankern; die Auswahl „Reopenings“ und
der Datenschutzhinweis bleiben erhalten.
