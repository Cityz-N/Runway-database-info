# Runway database

Personal-use viewer for runways of 2000 m or more worldwide, showing average slope and distances to every taxiway intersection. For flight simulation and VATSIM ATC practice only, not for real-world performance calculations.

## Files
- `index.html`: the whole app in one file (HTML, CSS and JS, no build step). Open it in a browser or host it on GitHub Pages.
- `LICENSE`: MIT, covers the code only. The data is downloaded live and is not in this repo. OpenStreetMap data must stay credited as "© OpenStreetMap contributors" (ODbL).

## Behaviour
- Dark theme only.
- The A− / A+ buttons (5 % steps) and the percent box in the header scale the whole page with CSS `zoom` on `body`, from 50 % to 200 %. The default is 115 %, and the choice is saved in localStorage under `rwy:zoom`.
- Clicking a runway in the list shows only that runway. Buttons under the airport name switch to its other runways, and a `#IDENT` link opens the longest one.
- Diagram labels: each is centred on its position (moved only to stay inside the diagram) and sits on the side of the runway its taxiway really leaves from, the longer side if it crosses. Two rows per side, or more if labels would otherwise overlap.
- Guessed (inferred) intersections are hidden by default, from both the diagram and the table. A checkbox below the diagram shows them, and the choice is saved under `rwy:showInf`.
- On screens 960 px and wider, the diagram and the table's column titles stay pinned while scrolling. `renderDetail` measures the diagram's height into `--diagram-h` so the titles sit right under it.
- The thin line joining a label to the runway takes the label's colour, so it stands apart from the faded taxiway shapes.
- Faded lines on the diagram show each taxiway's real shape near the runway, on its real side (up = left when moving from the `le` end). The runway's drawn width isn't to scale, but distance from its edge uses the same scale as its length, so angles are true.
- The runway diagram never flips: the `le` end is always on the left. Choosing a direction highlights that end, shows chevrons and updates the scale and the table.
- The list stays empty until the search box has at least 2 characters, and no airport opens by default (a `#IDENT` link still opens that airport). Export CSV ignores this: with no search it exports every runway matching the filters.

## Data sources (downloaded live by the page)
- **OurAirports** (public domain): `runways.csv` and `airports.csv` from `https://davidmegginson.github.io/ourairports-data/`, with raw.githubusercontent.com as fallback. Provides length, width, surface, threshold positions and elevations, and displaced thresholds.
- **OpenStreetMap via the Overpass API** (`overpass-api.de`, fallbacks `maps.mail.ru`, `overpass.kumi.systems`, `overpass.private.coffee`, started 10 s apart, first good answer wins, 100 s limit overall): `aeroway=runway` and `aeroway=taxiway` ways inside the airport's bounding box. Fetched for the whole airport the first time a runway's "Load intersections" button is clicked (each runway only shows its results once its own button is clicked) and cached in localStorage under `rwyx:<ident>` (schema `v: 5`; bump it whenever the computed results change, so old saved results are dropped).

## How values are computed
- **Slope** = (he_elevation_ft − le_elevation_ft) / length_ft × 100, as a percentage. Positive means uphill when using the `le` runway direction. The opposite direction is the negative.
- **Flags**: `none` = an end elevation is missing; `suspect` = both ends equal the field elevation (probably copied, so the 0 % is fake); `check` = |slope| > 2.5 %.
- **Intersections** (`processOSM`):
  1. Snap the runway axis to the matching OSM runway centreline. Runways split into several ways are handled. Falls back to the OurAirports end positions.
  2. Project each taxiway (and each crossing runway) onto the axis using a local equirectangular projection.
  3. Count a hit where a segment crosses the centreline at 15° or more, or where a taxiway ends within half the runway width + 15 m and then clears that band within 500 m. The second rule catches curved exits that join at a shallow angle (common at LFPG) while still excluding ways running along the runway. Parallel taxiways never get that close.
  4. Name unnamed taxiways from the named taxiways they share a node with (up to 3 ways away, not through a runway node, ignoring taxiways parallel to the runway, at most 2 names). When shown, these appear in orange with a dashed outline, a `~` prefix and a warning, because the name is inferred, not from OSM. Anything else stays "unnamed".
  5. Merge hits with the same name within 40 m of each other.
  6. For each direction, report the distance from the runway start, the distance from the threshold (minus the displaced threshold) and the take-off run remaining.
- Computed distances are **not** official intersection TORA, which subtracts a line-up allowance (see AIP AD 2.13).

## Known limits and ideas
- Public Overpass servers are often overloaded, so a load can take a minute or two, or fail and need a retry.
- OSM taxiway names (`ref`) are often missing at small fields; when no connected taxiway has a name either, these show as "unnamed".
- Possible upgrades: Navigraph DFD `tbl_pg_runways.runway_gradient` for slope, and Navigraph AMDB layers (Runway Threshold `rwyslope`, `tora`/`toda`/`asda`/`lda`, Runway Exit Line) for intersections. Both require Navigraph developer access and are licensed for personal use only, with no redistribution.
- Possible fallback for missing elevations: fit a slope from Copernicus GLO-30 samples along the centreline.
