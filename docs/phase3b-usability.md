# Phase 3B usability changes

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

## Year controls

Both interactive year sliders now start at 2026. A visible note states that 2026 covers only 1 January through 17 November. The top value boxes continue to show 2025 as the last completed calendar year: 2,084 administrative creations and 1,590 administrative closures.

Changing event type or NAF section does not alter the selected chart year. The chart data continue to use the validated public annual table and current-stock creation cohorts defined in Phase 3A.

## Methodology, About and navigation

The sidebar contains three internal navigation items: Dashboard, Methodology & Data, and About. Methodology & Data contains sources, definitions, geographic coverage, data quality, the public-coverage Sankey and limitations. About contains the project overview, technology, author, source-code link and the author logo.

All pages use the shared DemographyDE-aligned header, KPI cards, containers, colours and typography.

## Chart layout

The chart types and colour palette are unchanged. Layout improvements include:

- wrapping long French NAF section labels;
- a larger height for the activity lollipop chart;
- a wider left Plotly margin and automatic axis margins;
- additional spacing between axis titles, labels and plot title;
- responsive Plotly sizing with the logo removed from the tool bar;
- consistent top-right modebar placement with sufficient title margin.

## Shared-coordinate inspection

The internal SIRENE/BAN/IGN review is documented in `docs/internal-coordinate-review.md`. It confirms that nearly all same-coordinate groups share one normalized address and mostly represent distinct legal units. Two possible coordinate-convergence groups remain unchanged for future monitoring. No records were merged or removed.

## Aggregate map verification and pop-ups

The Phase 3D review retained the documented La Seyne-sur-Mer overview bounds and
the DemographyDE-style home button. Both year controls still start at 2026, the
partial-year note remains visible, and the headline annual values still use 2025.

The final public map has no establishment markers. It shows proportional circles
for released 500-m cell/section aggregates (`n >= 5`). Pop-ups contain only the
economic section, released count and an explicit aggregate-location warning.
The total view is the sum of released components only. The coverage line derives
the complete active stock and released spatial count from section aggregates.
The Methodology & Data Sankey additionally separates the 5,214 address-exact O/O
internal basis into 4,272 released and 942 threshold-excluded records.

Long activity labels are wrapped slightly earlier and the Plotly left margin is
balanced for narrower windows. Automatic axis margins, responsive sizing and
the existing chart types and colours are retained; the modebar is slightly
scaled on screens narrower than 900 pixels.
