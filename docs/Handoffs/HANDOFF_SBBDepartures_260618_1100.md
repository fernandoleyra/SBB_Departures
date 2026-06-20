# Handoff: SBBDepartures — UX Polish & Bug Fixes

**Created:** 2026-06-18 ~11:00
**Branch:** main
**Session Duration:** ~2 sessions (context compacted mid-session)

---

## Summary

Continued UX/UI polish on a macOS SwiftUI menu bar app (SBBDepartures) that tracks Swiss public transport departures. This session addressed a series of user-reported visual bugs post-redesign: white-on-white contrast, invisible dark-mode text, duplicate icons, cramped emoji pickers, grey sidebar names, and a non-responsive expand button in a ScrollView. All fixes committed. One persistent issue remains: the `···` expand button in WatchedLinesSection still doesn't always respond to the lightest clicks — two gesture fixes attempted (`onTapGesture` → `highPriorityGesture`).

---

## Work Completed

### Changes Made

- [x] Fixed white-on-white contrast: replaced `SBBStyle.milk/white/cloud` hardcoded hex backgrounds with `NSColor` semantic colors (`controlBackgroundColor`, `windowBackgroundColor`, `separatorColor`)
- [x] Rebuilt profile editor and new-watchlist modals from scratch as `.sheet` (replaced broken `.popover`) — `ProfileEditorSheet` + `NewWatchlistSheet`
- [x] Fixed dark mode invisible text: replaced all `SBBStyle.graphite` (#2D2D2D) text uses with `.foregroundStyle(.primary)`
- [x] Removed duplicate `+` from Add button label (`"+ Add"` → `"Add"`, icon provides the `+`)
- [x] Fixed sidebar watchlist names grey: added `.foregroundStyle(.primary)` to `SidebarProfileRow`
- [x] Fixed emoji grid too tight: changed 8-column layout to 4-column `LazyVGrid` with 12px spacing
- [x] Attempted fix for `···` expand button not responding: `Button` → `onTapGesture` (commit `1910463`)
- [x] Attempted fix again: `onTapGesture` → `highPriorityGesture` (commit `c78a5e5`)

### Key Decisions

| Decision | Rationale | Alternatives Considered |
|---|---|---|
| NSColor semantic colors over hex | Adapts to light/dark mode automatically | Hardcoded light+dark pairs |
| `.sheet` over `.popover` for modals | Better macOS HIG compliance, proper sizing | Keeping `.popover` |
| `highPriorityGesture` for expand button | Beats ScrollView's pan gesture | `onTapGesture`, `Button`, `NSGestureRecognizer` |
| 4-col emoji grid | Breathing room in 360px sheet without resizing window | 8-col cramped, 2-col too tall |

---

## Files Affected

### Modified

- `SBBDepartures/App/WatchedLinesSection.swift` — Semantic colors, `.primary` text, gesture fix for expand button, 4-col emoji grid context (the emoji grid is in ManagementWindowView)
- `SBBDepartures/App/ManagementWindowView.swift` — Full modal rebuild: `ProfileEditorSheet`, `NewWatchlistSheet`, semantic colors, sidebar `.primary` names, 4-col emoji grid
- `SBBDepartures/App/MenuBarPopoverView.swift` — Footer buttons `.buttonStyle(.bordered)` (was invisible `.plain`)
- `SBBDepartures/App/DeparturesAppState.swift` — Added `insertProfile(_:)` and `cancelRefresh()` public API

### Read (Reference)

- `SBBDepartures/App/SBBStyle.swift` — SBB palette + `LineBadge` + `badgeColor(for:)`

---

## Technical Context

### Architecture Notes

- macOS 13+ SwiftUI app with `MenuBarExtra` (menu bar icon) + `WindowGroup` (management window)
- `NavigationSplitView`: sidebar (watchlist list) + detail (departures + watched lines)
- `@EnvironmentObject var appState: DeparturesAppState` — single source of truth
- All UI color decisions: use `Color(NSColor.*)` semantic system colors, never hardcoded hex for backgrounds/borders
- `SBBStyle.graphite` is a DARK hex (#2D2D2D) — **never use as text color**, use `.primary`

### Gesture Architecture

- macOS `ScrollView` + `Button`: button may require prior scroll to activate (known SwiftUI bug)
- `onTapGesture`: better than `Button` but still participates in gesture arbitration
- `highPriorityGesture(TapGesture())`: intended to win over scroll pan gesture — current approach
- If still broken: consider `NSViewRepresentable` wrapper with `NSClickGestureRecognizer`

### Test Setup

- `AppStateTests` uses per-test `SharedStore` backed by unique temp file (avoids real app data bleed)
- All test methods call `appState.cancelRefresh()` immediately after init (prevents `WidgetCenter` crash)
- 21/21 tests pass (last verified before this session's fixes)

---

## Things to Know

### Gotchas & Pitfalls

- `SBBStyle.graphite` (#2D2D2D) is nearly black — **invisible on dark backgrounds**. Always use `.primary` for text.
- `SBBStyle.milk` (#F6F6F6) as background + `SBBStyle.white` (#FFFFFF) cards = invisible borders in light mode.
- `WidgetCenter.shared.reloadAllTimelines()` crashes test processes — `cancelRefresh()` must be called in test setup.
- SourceKit diagnostics in Claude Code show "Cannot find type" errors for `DeparturesAppState`, `FavoriteTransport`, `SBBStyle` in `WatchedLinesSection.swift` — these are **stale index errors**, not real build errors. The project builds and runs fine.

### Known Issues

- **`···` expand button may still not respond to very light clicks** — `highPriorityGesture` is the current fix (commit `c78a5e5`). If user still reports issues, next escalation is `NSViewRepresentable` with `NSClickGestureRecognizer(target:action:)` which bypasses SwiftUI gesture system entirely.

---

## Current State

### What's Working

- Menu bar popover: shows next departure per watched line, refresh, open/manage buttons ✅
- Management window: sidebar (watchlist list) + detail (departure board + watched lines) ✅
- Dark/light mode: all semantic colors adapt correctly ✅
- New Watchlist sheet: name, emoji picker (4-col), mode selector, Create/Cancel ✅
- Edit Watchlist sheet: same fields + delete option ✅
- Add Line panel: stop search + candidate lines with `+Add` button ✅
- Watched line rows: toggle enable, expand for walk/alert settings, remove ✅

### What's Not Working / Uncertain

- **`···` expand button**: may still miss the lightest clicks (highPriorityGesture is latest attempt)

### Tests

- [x] Unit tests: 21/21 passing (AppStateTests + SBBStyleTests)
- [ ] Manual testing of highPriorityGesture fix not confirmed by user yet

---

## Next Steps

### Immediate (Start Here)

1. **Test the `···` button fix** — user should open the app and try clicking `···` on a watched line without scrolling first. If still unresponsive, escalate to `NSViewRepresentable` + `NSClickGestureRecognizer`.
2. **If still broken**: in `WatchedLinesSection.swift` around line 138, replace the `Image + highPriorityGesture` block with an `NSViewRepresentable` click wrapper.
3. **Run tests** to confirm all 21 still pass after gesture change: `xcodebuild test -scheme SBBDepartures -destination 'platform=macOS'`

### Subsequent

- Review any remaining UX issues the user finds after testing
- Consider adding platform for departures in the quick view row
- Consider showing next 2-3 departures per line instead of just the soonest

### Blocked On

- User testing the `highPriorityGesture` fix to confirm if it resolved the issue

---

## Related Resources

### Commands to Run

```bash
# Build
xcodebuild build -scheme SBBDepartures -destination 'platform=macOS'

# Test
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS'

# Git log
cd /Users/leyra/Documents/Codex/2026-06-16/create-a-local-macbook-desktop-plugin && git log --oneline -10
```

### Key File Locations

- App entry: `SBBDepartures/SBBDeparturesApp.swift`
- State: `SBBDepartures/App/DeparturesAppState.swift`
- Style: `SBBDepartures/App/SBBStyle.swift`
- Menu bar popover: `SBBDepartures/App/MenuBarPopoverView.swift`
- Management window: `SBBDepartures/App/ManagementWindowView.swift`
- Watched lines: `SBBDepartures/App/WatchedLinesSection.swift`
- Tests: `SBBDeparturesTests/AppStateTests.swift`

---

## Recent Commits This Session

```
c78a5e5 fix: use highPriorityGesture for expand button to beat ScrollView pan gesture
1910463 fix: use onTapGesture for expand button to avoid ScrollView tap-delay on macOS
e2c11df fix: sidebar name .primary color; emoji grid 4-col with 12px spacing for breathing room
2d48e46 fix: remove duplicate + from Add button label
ec39d91 fix: replace hardcoded graphite text color with .primary for dark mode legibility
2f4a01a fix: improve UI contrast and rebuild profile/watchlist sheets from scratch
```
