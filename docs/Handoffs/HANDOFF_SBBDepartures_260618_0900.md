# Handoff: SBBDepartures UX Redesign — Complete

**Created:** 2026-06-18
**Branch:** main
**Session:** Tasks 3–8 of 8-task UX/UI redesign plan

---

## Summary

An 8-task macOS SwiftUI UX/UI redesign of SBBDepartures (Swiss public transport menu bar app) was completed across two sessions. The app now has a 420px quick-glance `MenuBarExtra` popover as the primary surface and one unified `ManagementWindowView` (NavigationSplitView) replacing three fragmented legacy views. All 21 tests pass, release build succeeds, and a whole-branch reviewer issued APPROVED_WITH_NOTES with zero blocking defects.

---

## Work Completed

### This Session (Tasks 3–8)

- [x] **Task 3** — Rewrote `MenuBarPopoverView` as 420px quick-glance surface with 3 states (no-permission, no-profile, departures list), `LineBadge` + `badgeColor`, ′ symbol, `openWindow(id: "management")` navigation
- [x] **Task 4** — Created `ManagementWindowView` with `NavigationSplitView`, `SidebarProfileRow`, `ProfileDetailHeader`, `ProfileEditorPopover`, `DepartureBoardSection`, `DepartureBoardRow`, `WatchedLinesSection` stub
- [x] **Task 4 fixes** — Code review resolved: `SBBStyle.white` token added, `dashboardSnapshots` double-compute fixed, `DepartureBoardRow` accessibility label includes delay
- [x] **Task 5** — Created `WatchedLinesSection` with `WatchedLineRow` (toggle, walk minutes, alert threshold, delete), `AddLinePanel` (search/nearby, stop picker, candidate lines with duplicate prevention), removed stub from `ManagementWindowView`
- [x] **Task 6** — Rewrote `SBBDeparturesApp.swift` to use `WindowGroup(id: "management")` + `ManagementWindowView`; deleted `DashboardView.swift` and `SettingsView.swift`; full test suite green
- [x] **Task 7** — Widget: replaced plain text line display with `LineBadge` + `badgeColor`, `.red` delay → `SBBStyle.redDark`
- [x] **Task 8** — Final verification: stray `.orange` in widget stale icon replaced with `Color(hex: SBBPalette.orangeHex)`; all grep checks clean; release build pass

### Previous Session (Tasks 1–2)

- [x] **Task 1** — `SBBPalette` + `SBBStyle` color tokens, `badgeColor(for:)`, `LineBadge` with explicit color, `SBBStyleTests` (9 tests)
- [x] **Task 2** — `hasFavorite()`, `addProfile(mode:)`, `cancelRefresh()`, `AppStateTests` (5 tests), `lazy var` fix for `UNUserNotificationCenter`

---

## Files Affected

### Created

- `SBBDepartures/App/MenuBarPopoverView.swift` — full rewrite (420px popover)
- `SBBDepartures/App/ManagementWindowView.swift` — new management window
- `SBBDepartures/App/WatchedLinesSection.swift` — watched lines + Add Line panel
- `SBBDeparturesTests/AppStateTests.swift` — 5 unit tests for AppState helpers

### Modified

- `SBBDepartures/App/SBBDeparturesApp.swift` — rewrote scenes: `WindowGroup(id: "management")`, removed `Settings` scene
- `SBBDepartures/App/DeparturesAppState.swift` — added `hasFavorite()`, `addProfile(mode:)`, `cancelRefresh()`; `refreshTask` stays `private`
- `SBBDepartures/App/SBBStyle.swift` — added `SBBPalette.whiteHex` + `SBBStyle.white` token
- `SBBDepartures/Shared/Models.swift` — `DepartureLogic.normalize()` made `internal` (was `private`)
- `SBBDepartures/Shared/NotificationService.swift` — `center` changed to `lazy var` to avoid test crash
- `SBBDepartures/Widget/DeparturesWidget.swift` — `LineBadge` + `badgeColor`, `redDark` delay, `SBBPalette.orangeHex` stale icon
- `SBBDepartures.xcodeproj/project.pbxproj` — registered all new files in all three targets as needed

### Deleted

- `SBBDepartures/App/DashboardView.swift` — replaced by `ManagementWindowView`
- `SBBDepartures/App/SettingsView.swift` — replaced by `ManagementWindowView` + `WatchedLinesSection`

---

## Technical Context

### Design Token System

`SBBPalette` holds hex strings; `SBBStyle` holds `Color` values. Both live in `SBBStyle.swift` which is compiled into all three targets. `badgeColor(for:)` takes a category string (e.g. "IC", "IC 5", "S3") and returns the correct brand color. Check-order matters: STR/NFT/T before S; NFB/B before B; BAT/CGN before B.

### Test Isolation Pattern

`AppStateTests` must use `makeAppState()` which passes a unique temp-file `SharedStore` to avoid reading real user data from the app group container. Always call `appState.cancelRefresh()` immediately after construction to stop the background refresh loop that would crash during test teardown.

### project.pbxproj UUID Convention

Session-added UUIDs follow pattern `A000...20XX` (file references) and `A000...10XX` (build files). Current high watermark: file ref `201B`, build file `100D` for app target; `1207–120A` for test target additions.

### Two-Surface Architecture

```
MenuBarExtra (id implicit)    →  MenuBarPopoverView  (420px, quick-glance)
WindowGroup(id: "management") →  ManagementWindowView (780×540 min, full CRUD)
```

Popover navigates to management window via `@Environment(\.openWindow)` with `id: "management"`.

---

## Things to Know

### Gotchas

- `UNUserNotificationCenter.current()` crashes in test processes if called eagerly — must stay `lazy var` in `NotificationService.swift`
- `DeparturesAppState()` default init uses `SharedStore.shared` which reads the real app group container — tests must always use `makeAppState()` with a temp file URL
- `project.pbxproj` is hand-edited; always run `plutil -lint` after editing; never use Xcode's "Add files" dialog as it will generate random UUIDs that break the pattern
- `refreshTask` is `private` — the only way to cancel it externally is `cancelRefresh()`

### Reviewer Notes (APPROVED_WITH_NOTES — all minor)

1. Popover shows raw nearby-stop departures (all lines from 3 nearest stops), not the watchlist. Matches existing auto-mode behavior. Product decision if this should change.
2. "Open" and "Manage" footer buttons in popover both call `openWindow(id: "management")` with no differentiation. Spec wanted "Manage" to scroll to WatchedLinesSection — needs `ScrollViewReader`/`scrollTo`.
3. `AddLinePanel` has no `.keyboardShortcut(.cancelAction)` for Escape. Non-blocking.
4. `addProfile()` does not auto-focus the name field. Minor spec deviation.

---

## Current State

### What's Working

- Full app builds (debug + release)
- 21/21 tests pass
- `MenuBarExtra` popover at 420px with quick-glance departures
- `ManagementWindowView` with sidebar profile switcher, departure board (up to 12 rows), profile editor popover
- `WatchedLinesSection` with per-line enable toggle, walk minutes, alert threshold, remove with confirmation
- `AddLinePanel` with search/nearby, stop picker, candidate lines, duplicate prevention ("already saved"), just-added feedback
- Widget uses `LineBadge` + `badgeColor`, `redDark` for delays

### What's Not Working / Open

- Popover "Manage" button doesn't scroll to WatchedLinesSection (both buttons do same thing)
- No Escape keyboard shortcut to close `AddLinePanel`
- No auto-focus on profile name field after adding new profile

### Tests

- [x] Unit tests: 21 passing (AppStateTests 5, SBBStyleTests 9, FixtureTests 3, DepartureLogicTests 4)
- [ ] UI/integration tests: not written (out of scope for this plan)
- [x] Manual build verification: debug + release both BUILD SUCCEEDED

---

## Next Steps

### Immediate (Start Here)

There are no required next steps — the 8-task redesign plan is complete. The app is in a shippable state.

### Optional Enhancements (from reviewer notes)

1. **Manage button scroll** — In `MenuBarPopoverView`, give the `WatchedLinesSection` a named scroll anchor and use `ScrollViewReader.scrollTo` when "Manage" is tapped
2. **Escape to close AddLinePanel** — Add `.keyboardShortcut(.cancelAction)` to the close button in `AddLinePanel`
3. **Auto-focus profile name** — After `addProfile()`, set focus to the name `TextField` in `ProfileEditorPopover` using `@FocusState`
4. **Per-keystroke persist debounce** — In `ProfileEditorPopover`, buffer the name `TextField` in `@State` and commit only on `onSubmit`/popover dismiss

### Subsequent

- App Store / notarization preparation
- Localization (German/French for Swiss market)
- iCloud sync for watchlists across devices

---

## Related Resources

### Plan File

`docs/superpowers/plans/2026-06-17-sbb-departures-ux-redesign.md` — full 8-task plan (now complete)

### Task Reports

`.git/sdd/task-1-report.md`, `.git/sdd/task-2-report.md`, `.git/sdd/tasks-3-8-report.md`

### Commands

```bash
# Build
xcodebuild build -scheme SBBDepartures -destination 'platform=macOS'

# Test
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'passed|failed|error:'

# Stray ref check
grep -rn "DashboardView\|SettingsView\|SBBBrandHeader\|ManageSheetView" SBBDepartures/ && echo "FOUND" || echo "CLEAN"

# System color check
grep -rn "\.foregroundStyle(\.red)\|\.foregroundStyle(\.orange)" SBBDepartures/ | grep -v "\.role"

# pbxproj lint
plutil -lint SBBDepartures.xcodeproj/project.pbxproj
```

---

## Open Questions

- [ ] Should the popover show only watchlist departures (filtered) vs. all nearby departures? (product decision)
- [ ] Target macOS version for App Store submission?
- [ ] App group container ID for production vs. development?

---

## Session Notes

The whole-branch reviewer (run at end of session) confirmed APPROVED_WITH_NOTES with all findings classified as Minor. The three important code-review findings from Task 4 (raw `.white`, double-compute in `ForEach`, missing delay in a11y label) were fixed before Task 5 began. The final stray system color (`.orange` in widget stale icon) was caught in Task 8's grep check and fixed inline.
