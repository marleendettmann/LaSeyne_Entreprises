# Current v6 usability and presentation

This page describes the current public `grid500_privacy_v6_simplified`
application. Earlier experimental historical section filters, interval controls
and establishment-level map views are not part of the public release.

## Map navigation

The Leaflet map now has a home button directly below the standard zoom controls. It uses the same `easyButton` and JavaScript `map.fitBounds()` approach as DemographyDE.

The fixed overview extent is:

- west: 5.842;
- south: 43.060;
- east: 5.914;
- north: 43.124.

The extent concentrates the initial view on La Seyne-sur-Mer. Both the initial
map and the home button use these bounds, independently of the selected NAF
section. The button changes only the viewport; it does not modify aggregate
circles, filters or data.

Economic-section changes now update the aggregate layers with
`leafletProxy()`, so the current zoom and extent are retained. At zoom level 15
and above, subtle outlines and a 10% fill appear for only the already released
500 m cells in the current selection. Proportional circles remain the primary
citywide encoding and are drawn above these contextual cells. Both layer types
use the same released section/count pop-up; no suppressed cell or complete grid
is sent to the browser.

## Historical controls

The left historical chart has one event selector for municipality-wide annual
administrative creations, closures and reopenings. Because exactly one series
is displayed at a time, the control is an inline radio group styled as three
large buttons; it wraps vertically on narrow screens. It has no economic-section
filter or interval selector. Missing observations remain gaps and are not
converted to zero.

The right historical chart has one year slider, initially set to 2026. A visible
note states that 2026 covers only 1 January through 17 November. The top value
boxes continue to show 2025 as the last completed calendar year: 2,084
administrative creations and 1,590 administrative closures. The historical
charts use only the validated municipality-wide annual table.

## Methodology, About and navigation

The sidebar contains three internal navigation items: Dashboard, Methodology and Data, and About. Methodology and Data contains sources, definitions, geographic coverage, data quality, the public-coverage Sankey and limitations. About contains the project overview, technology, author, source-code link and the author logo.

All pages use the shared DemographyDE-aligned header, KPI cards, containers, colours and typography.
The header uses anthracite `#27313A`, white text and the established orange
accent line. Dashboard, Methodology and Data and About share a compact source
footer with links to Insee SIRENE, IGN and Licence Ouverte 2.0.

## Chart layout

The current chart layout includes:

- an area-and-line chart for municipality-wide annual register events;
- a year-specific column chart for the three event types;
- a horizontal orange dot/lollipop chart for the eight largest current NAF
  sections and creation years 2015–2026;
- readable margins and automatic axis margins;
- additional spacing between axis titles, labels and plot title;
- responsive Plotly sizing with the logo removed from the tool bar;
- consistent top-right modebar placement with sufficient title margin.

The third chart uses a separate year slider and starts at 2026. It displays
only eight precomputed values for the selected year; 2026 is visibly marked as
incomplete through 17 November. The chart concerns registered creation years of
establishments active at the reference date, not all historical creations.

## Aggregate map verification and pop-ups

The current release retains the documented La Seyne-sur-Mer overview bounds and
the DemographyDE-style home button. The single year slider starts at 2026, the
partial-year note remains visible, and the headline annual values use 2025.

The final public map has no establishment markers. It shows proportional circles
for released 500-m cell/section aggregates (`n >= 5`). Pop-ups contain only the
economic section, released count and an explicit aggregate-location warning.
The total view is the sum of released components only. The coverage line derives
the complete active stock and released spatial count from section aggregates.
No suppressed residual is assigned to or published for an individual grid cell.
Because section-level aggregation-basis totals and released counts are public,
the total number excluded by the threshold can nevertheless be derived for an
economic section; its distribution among suppressed cells cannot.
The Methodology and Data Sankey additionally separates the 5,214 address-exact O/O
internal processing basis into 4,272 released and 942 threshold-excluded records.

Automatic axis margins, responsive sizing and the established colours are
retained; the modebar is slightly scaled on screens narrower than 900 pixels.
