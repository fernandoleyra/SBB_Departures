# SBB Departures — UX/UI Redesign

**Date:** 2026-06-17  
**Scope:** Full UX/UI redesign from scratch using Apple HIG  
**Approach:** Approach B — menu bar popover as primary surface, dedicated Management Window for all editing

---

## Problem Summary

The current app has three parallel management UIs (`DashboardView`, `ManageSheetView`, `SettingsView`) that are inconsistent with each other. The add-to-watchlist flow has no duplicate prevention and no feedback. Destructive actions have no confirmation. All transport badges are the same red regardless of type. The menu bar popover is noisy and inconsistent with the main window.

---

## Architecture

### Surface hierarchy

1. **Menu bar popover** — primary surface. Quick glance only. Always shows location-based departures.
2. **Management Window** — secondary. Full departure board + watchlist editing. Opened explicitly from the popover.

The current `DashboardView`, `ManageSheetView`, and `SettingsView` are consolidated into a single `ManagementWindowView`.

### App entry points

| Entry | Opens |
|---|---|
| Click menu bar icon | `MenuBarPopoverView` (quick view) |
| "Open" in popover | `ManagementWindowView` (main window) |
| "Manage" in popover | `ManagementWindowView`, editor focused |

---

## Surface 1 — Menu Bar Popover (Quick View)

**Width:** 420px fixed. Height: content-driven, no scroll.  
**Purpose:** Single glance at the next departure per watched line from the location-linked profile. Nothing more.

### Normal state

```
┌──────────────────────────────────────────┐
│  📍 Zürich Stadelhofen          2m ago ↻ │
│ ──────────────────────────────────────── │
│   3′  [IC 5]  → Bern             18:14  │
│   7′  [S3  ]  → Zürich HB        18:17  │
│  11′  [31  ]  → Spital           18:21  │
│ ──────────────────────────────────────── │
│  Open                     ⚙ Manage      │
└──────────────────────────────────────────┘
```

- Shows **1 row per watched line/direction** — the single next departure only
- Location comes from the profile with `mode == .automatic`
- Minutes use ′ symbol consistently
- `LineBadge` uses transport-type color (see Color System)
- Refresh button (↻) in header; spinner replaces it during active fetch
- "2m ago" timestamp; turns amber after 5 minutes stale

### No location permission state

```
┌──────────────────────────────────────────┐
│  📍 Location needed                      │
│  [Allow Location Access]                 │
│ ──────────────────────────────────────── │
│  Open                     ⚙ Manage      │
└──────────────────────────────────────────┘
```

### No location-linked profile state

```
┌──────────────────────────────────────────┐
│  📍 No location watchlist set up         │
│  [Create Nearby Watchlist →]             │
│ ──────────────────────────────────────── │
│  Open                     ⚙ Manage      │
└──────────────────────────────────────────┘
```

Tapping "Create Nearby Watchlist →" creates an automatic-mode profile and switches to Management Window.

### Behavior rules

- Location is fetched on every popover open (lightweight nearby-stops query)
- Maximum visible rows: all watched lines for the location profile, 1 departure each
- Delay shown inline: `18:14 +3′` in `SBBStyle.redDark`
- Platform shown as a small label after the time when non-empty
- "Open" opens `ManagementWindowView` on the active profile's departure board
- "Manage" opens `ManagementWindowView` scrolled to the Watched Lines section

---

## Surface 2 — Management Window

**Minimum size:** 780 × 540px (reduced from 880 × 620).  
**Structure:** `NavigationSplitView` — sidebar (watchlists) + detail (departure board + lines editor).

### Sidebar

```
Watchlists                    [+]
──────────────────────────────
🏠 Home                    ✓
💼 Office
📍 Nearby
```

- `[+]` adds a new watchlist instantly; new row enters edit mode (name field focused)
- Active profile shows a checkmark
- Right-click or swipe-left on a row reveals "Delete" — triggers `.confirmationDialog`
- Sidebar minimum width: 180px

### Detail panel — header

```
🏠 Home                                              [···]
```

`[···]` opens a popover with:
- Emoji picker (8 choices: 🏠 💼 📍 🚆 ⭐️ 🎒 ☕️ 🏫)
- Name `TextField`
- Mode: `Picker` — Manual / Auto (location)
- "Delete Watchlist" button (destructive, `.confirmationDialog` shows line count)

### Detail panel — departure board section

```
NEXT DEPARTURES                                       [↻]
┌──────────────────────────────────────────────────────┐
│   5′  [IC 5]  → Bern                         18:14  │
│   8′  [S3  ]  → Zürich HB                    18:17  │
│  12′  [31  ]  → Spital                       18:21  │
└──────────────────────────────────────────────────────┘
```

- Shows all upcoming departures for active profile, sorted by time
- Same `LineBadge` color system as popover
- Auto-mode profile shows live nearby departures here
- Empty state: "No departures — add a watched line below"

### Detail panel — watched lines section

```
WATCHED LINES                                      [+ Add]
┌──────────────────────────────────────────────────────┐
│  ● [IC 5]  → Bern          Zürich HB           ···  │
│  ● [S3  ]  → Zürich HB     Zürich HB           ···  │
│  ● [31  ]  → Spital        Zürich HB           ···  │
└──────────────────────────────────────────────────────┘
```

- `●` toggle enables/disables the line without deleting it (`.toggle` style, tinted SBB red when on)
- `···` expands the row inline:

```
│  ● [IC 5]  → Bern          Zürich HB           ···  │
│ ──────────────────────────────────────────────────── │
│  Walk time  [__5__] min     Alert  [✓]  [__7__] min  │
│                                            [Remove]  │
```

  - Walk time: plain number `TextField` + "min" label (replaces `Stepper`)
  - Alert: `Toggle` + number `TextField` for lead minutes (only visible when toggle is on)
  - `[Remove]`: destructive button → `.confirmationDialog`:

```
"Remove IC 5 → Bern?
 This will stop showing this departure."
[Cancel]  [Remove]
```

### Delete watchlist confirmation

```
"Delete Home?
 This removes 3 saved lines and all departure data."
[Cancel]  [Delete]
```

---

## Surface 3 — Add Line Flow (inline panel)

Tapping `[+ Add]` expands a panel below the Watched Lines section. No separate sheet or modal.

### Panel layout

```
ADD A LINE                                        [✕ Close]
──────────────────────────────────────────────────────────
[🔍 Search stop]                    [📍 Near me]

┌────────────────────────────────────────────┐  [Search]
│  Zürich HB                                 │
└────────────────────────────────────────────┘

① STOP                  ② LINE / DIRECTION
──────────────────────  ──────────────────────────────────
Zürich HB          ✓   [IC 5]  → Bern                [+ Add]
Zürich Enge            [IC 5]  → Basel   already saved ──────
                        [S3  ]  → Stadelhofen         [+ Add]
                        [31  ]  → Spital              [+ Add]
```

### Add Line rules

- Already-saved lines show "already saved" label and no `[+ Add]` — **duplicates impossible**
- Tapping `[+ Add]` adds the line immediately; button shows `✓ Added` for 1.5s then the line disappears from the candidate list (it moved to Watched Lines)
- Panel stays open for adding more lines
- `[✕ Close]` or Escape collapses the panel
- Column widths: stop column flexible (min 200px), line column takes remaining space
- Both columns scroll independently if the list is long

### Near Me state

```
[📍 Near me — Zürich Stadelhofen, 80m]        [↻ Refresh]
──────────────────────────────────────────────────────────
Zürich Stadelhofen  ✓     [IC 5]  → Bern            [+ Add]
Zürich Bellevue           [S3  ]  → Zürich HB       [+ Add]
```

- Stop name + distance shown in the source toggle label once location resolves
- Stops sorted by distance ascending

### No location permission state

```
📍 Location access needed to find nearby stops.
[Allow Location Access]
```

---

## Color System

### LineBadge — transport category colors

| Category prefix | Transport type | Color token | Hex |
|---|---|---|---|
| IC, IR, EC, EN | Intercity / Express | `SBBStyle.red` | `#EB0000` |
| RE, RB | Regional train | `SBBStyle.redDark` | `#C60018` |
| S | S-Bahn | `SBBStyle.green` | `#2E7D32` |
| B, NFB | Bus | `SBBStyle.blue` | `#1F6AA5` |
| T, NFT, str | Tram | `SBBStyle.violet` | `#7B3FA1` |
| N | Night service | `SBBStyle.graphite` | `#2D2D2D` |
| BAT, CGN | Boat | `SBBStyle.teal` (new) | `#006E7F` |
| *(fallback)* | Unknown | `SBBStyle.graphite` | `#2D2D2D` |

`SBBPalette` gains one new entry: `tealHex = "#006E7F"`.  
`SBBStyle` gains `teal`, `green`, `blue`, `violet` computed vars (palette already has the hex values).

### Badge color resolution

```swift
static func badgeColor(for category: String) -> Color {
    let c = category.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    switch c {
    case let x where x.hasPrefix("IC") || x.hasPrefix("IR") || x.hasPrefix("EC") || x.hasPrefix("EN"):
        return SBBStyle.red
    case let x where x.hasPrefix("RE") || x.hasPrefix("RB"):
        return SBBStyle.redDark
    case let x where x.hasPrefix("STR") || x.hasPrefix("NFT") || x.hasPrefix("T"):
        return SBBStyle.violet  // tram — checked before "S" to avoid S-Bahn false match
    case let x where x.hasPrefix("S"):
        return SBBStyle.green
    case let x where x.hasPrefix("NFB") || x.hasPrefix("B"):
        return SBBStyle.blue    // NFB before B for same reason
    case let x where x.hasPrefix("BAT") || x.hasPrefix("CGN"):
        return SBBStyle.teal
    case let x where x.hasPrefix("N"):
        return SBBStyle.graphite
    default:
        return SBBStyle.graphite
    }
}
```

### Semantic color fixes

| Element | Before | After |
|---|---|---|
| Delay text (popover) | `.red` (system) | `SBBStyle.redDark` |
| Delay text (dashboard) | `SBBStyle.redDark` | `SBBStyle.redDark` (unchanged, now consistent) |
| Stale data banner | `.orange` (system) | `Color(hex: SBBPalette.orangeHex)` |
| Destructive buttons | mix of `SBBStyle.red` + `.red` | SwiftUI `.red` role (system red — correct for destructive UI) |
| Active toggle | `SBBStyle.red` tint | `SBBStyle.red` (unchanged, already correct) |

### Removed

- `SBBBrandHeader` component — the fake SBB logo (SF Symbol arrows + "SBB" text) is removed entirely. Section headers in the Management Window use plain `Text` with `.headline` style.

---

## Widget — DeparturesWidget

No structural changes. Two fixes only:

1. `LineBadge` receives transport-category color (same `badgeColor` function)
2. Delay text: `.red` → `SBBStyle.redDark`

---

## Files Affected

| File | Change type |
|---|---|
| `SBBStyle.swift` | Add `teal`, `green`, `blue`, `violet` color vars; add `badgeColor(for:)` function; add `tealHex` to `SBBPalette`; remove `SBBBrandHeader` |
| `MenuBarPopoverView.swift` | Full rewrite — quick view only, 3 states, 1 row per line |
| `DashboardView.swift` | Replaced by `ManagementWindowView.swift` |
| `SettingsView.swift` | Removed — functionality merged into `ManagementWindowView` |
| `ManagementWindowView.swift` | New file — unified sidebar + detail + add flow |
| `SBBDeparturesApp.swift` | Remove `Settings` scene; `WindowGroup` opens `ManagementWindowView`; remove `DashboardView` import |
| `DeparturesWidget.swift` | Apply `badgeColor`; fix delay color |
| `DeparturesAppState.swift` | No structural changes; `menuBarTitle` logic unchanged |
| `Models.swift` | No changes |

---

## HIG Compliance Notes

- All destructive actions use `.confirmationDialog` — no instant deletes
- Navigation uses `NavigationSplitView` with `.sidebar` list style
- Keyboard shortcuts: Escape closes the Add Line panel; default action (⏎) on the "Done" button
- Minimum window size reduced to 780 × 540 (more appropriate for a utility)
- No custom chrome, fake logos, or non-standard controls
- `Form` not used (detail panel is a free-form scroll, not a settings form)
- Profile switching via sidebar selection, not a floating segmented control
