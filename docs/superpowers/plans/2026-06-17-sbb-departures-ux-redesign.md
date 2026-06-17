# SBB Departures UX/UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the SBB Departures macOS app UX/UI from scratch — menu bar popover as a quick-glance primary surface, one unified Management Window replacing three fragmented views, proper transport-type badge colors, and confirmation dialogs on all destructive actions.

**Architecture:** Menu bar popover (420px, read-only) shows 1 departure per watched line from the location-linked profile. A single `ManagementWindowView` (`NavigationSplitView`) replaces `DashboardView` + `ManageSheetView` + `SettingsView`. Add-line flow is an inline expandable panel with duplicate prevention.

**Tech Stack:** Swift 5.9+, SwiftUI, macOS 13+, XCTest, SBB Transport Open Data API (existing `TransportAPI.swift`)

## Global Constraints

- Target: macOS 13+ (NavigationSplitView, openWindow environment required)
- All destructive actions require `.confirmationDialog` — no instant deletes anywhere
- `LineBadge` always receives a `color` parameter; default is `SBBStyle.red` for backward compat
- `SBBBrandHeader` is removed entirely — no replacement, just delete all usages
- Minutes always display with ′ symbol (prime, U+2032), never bare digits
- Delay text always uses `SBBStyle.redDark`, never system `.red`
- Stale banner always uses `Color(hex: SBBPalette.orangeHex)`, never system `.orange`
- Working directory for all commands: `/Users/leyra/Documents/Codex/2026-06-16/create-a-local-macbook-desktop-plugin`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `SBBDepartures/App/SBBStyle.swift` | Modify | Add color vars, `badgeColor(for:)`, remove `SBBBrandHeader` |
| `SBBDepartures/App/DeparturesAppState.swift` | Modify | Add `hasFavorite`, `addProfile(mode:)`, expose `normalize` |
| `SBBDepartures/App/MenuBarPopoverView.swift` | Rewrite | Quick view — 3 states, 1 row per line |
| `SBBDepartures/App/ManagementWindowView.swift` | Create | Sidebar + profile header + departure board |
| `SBBDepartures/App/WatchedLinesSection.swift` | Create | Watched lines list + expandable rows + Add Line panel |
| `SBBDepartures/App/SBBDeparturesApp.swift` | Modify | Window IDs, remove Settings scene |
| `SBBDepartures/App/DashboardView.swift` | Delete | Replaced by ManagementWindowView |
| `SBBDepartures/App/SettingsView.swift` | Delete | Replaced by ManagementWindowView + WatchedLinesSection |
| `SBBDepartures/Widget/DeparturesWidget.swift` | Modify | Apply `badgeColor`, fix delay color |
| `SBBDeparturesTests/SBBStyleTests.swift` | Create | Unit tests for `badgeColor` |
| `SBBDeparturesTests/AppStateTests.swift` | Create | Unit tests for `hasFavorite` |

---

## Task 1: Color System

**Files:**
- Modify: `SBBDepartures/App/SBBStyle.swift`
- Create: `SBBDeparturesTests/SBBStyleTests.swift`

**Interfaces:**
- Produces: `SBBStyle.badgeColor(for category: String) -> Color`
- Produces: `SBBStyle.green`, `SBBStyle.blue`, `SBBStyle.violet`, `SBBStyle.teal` (Color)
- Produces: `SBBPalette.tealHex` (String)
- Produces: `LineBadge(text: String, color: Color = SBBStyle.red)` — updated initializer

- [ ] **Step 1: Write failing tests**

Create `SBBDeparturesTests/SBBStyleTests.swift`:

```swift
import XCTest

final class SBBStyleTests: XCTestCase {
    func test_badgeColor_intercity() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "IC"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "IC 5"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "IR"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "EC"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "EN"), SBBStyle.red)
    }

    func test_badgeColor_regional() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "RE"), SBBStyle.redDark)
        XCTAssertEqual(SBBStyle.badgeColor(for: "RB"), SBBStyle.redDark)
    }

    func test_badgeColor_sbahn() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "S"), SBBStyle.green)
        XCTAssertEqual(SBBStyle.badgeColor(for: "S3"), SBBStyle.green)
        XCTAssertEqual(SBBStyle.badgeColor(for: "S 7"), SBBStyle.green)
    }

    func test_badgeColor_tram_not_confused_with_sbahn() {
        // STR must be checked before S to avoid collision
        XCTAssertEqual(SBBStyle.badgeColor(for: "STR"), SBBStyle.violet)
        XCTAssertEqual(SBBStyle.badgeColor(for: "T"), SBBStyle.violet)
        XCTAssertEqual(SBBStyle.badgeColor(for: "NFT"), SBBStyle.violet)
    }

    func test_badgeColor_bus() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "B"), SBBStyle.blue)
        XCTAssertEqual(SBBStyle.badgeColor(for: "NFB"), SBBStyle.blue)
        XCTAssertEqual(SBBStyle.badgeColor(for: "NFB 67"), SBBStyle.blue)
    }

    func test_badgeColor_boat() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "BAT"), SBBStyle.teal)
        XCTAssertEqual(SBBStyle.badgeColor(for: "CGN"), SBBStyle.teal)
    }

    func test_badgeColor_night() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "N"), SBBStyle.graphite)
        XCTAssertEqual(SBBStyle.badgeColor(for: "N5"), SBBStyle.graphite)
    }

    func test_badgeColor_fallback_for_number_only_routes() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "31"), SBBStyle.graphite)
        XCTAssertEqual(SBBStyle.badgeColor(for: ""), SBBStyle.graphite)
    }

    func test_badgeColor_case_insensitive() {
        XCTAssertEqual(SBBStyle.badgeColor(for: "ic 5"), SBBStyle.red)
        XCTAssertEqual(SBBStyle.badgeColor(for: "s3"), SBBStyle.green)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS' -only-testing:SBBDeparturesTests/SBBStyleTests 2>&1 | grep -E 'error:|FAILED|PASSED|badgeColor'
```

Expected: compile error — `badgeColor` does not exist yet.

- [ ] **Step 3: Implement color system in SBBStyle.swift**

Replace the entire contents of `SBBDepartures/App/SBBStyle.swift` with:

```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(cleaned, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

enum SBBPalette {
    static let redHex = "#EB0000"
    static let redDarkHex = "#C60018"
    static let milkHex = "#F6F6F6"
    static let cloudHex = "#E5E5E5"
    static let metalHex = "#DCDCDC"
    static let graphiteHex = "#2D2D2D"
    static let blueHex = "#1F6AA5"
    static let greenHex = "#2E7D32"
    static let violetHex = "#7B3FA1"
    static let orangeHex = "#D86B00"
    static let tealHex = "#006E7F"
}

enum SBBStyle {
    static let red      = Color(hex: SBBPalette.redHex)
    static let redDark  = Color(hex: SBBPalette.redDarkHex)
    static let milk     = Color(hex: SBBPalette.milkHex)
    static let cloud    = Color(hex: SBBPalette.cloudHex)
    static let graphite = Color(hex: SBBPalette.graphiteHex)
    static let blue     = Color(hex: SBBPalette.blueHex)
    static let green    = Color(hex: SBBPalette.greenHex)
    static let violet   = Color(hex: SBBPalette.violetHex)
    static let teal     = Color(hex: SBBPalette.tealHex)

    // Returns the SBB brand color for a transport category string.
    // Accepts raw category ("IC"), combined display ("IC 5"), or lowercase ("ic 5").
    // STR/NFT/T are checked before S to prevent S-Bahn false match.
    // NFB is checked before B for the same reason.
    static func badgeColor(for category: String) -> Color {
        let c = category.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch c {
        case let x where x.hasPrefix("IC") || x.hasPrefix("IR") || x.hasPrefix("EC") || x.hasPrefix("EN"):
            return red
        case let x where x.hasPrefix("RE") || x.hasPrefix("RB"):
            return redDark
        case let x where x.hasPrefix("STR") || x.hasPrefix("NFT") || x.hasPrefix("T"):
            return violet
        case let x where x.hasPrefix("S"):
            return green
        case let x where x.hasPrefix("NFB") || x.hasPrefix("B"):
            return blue
        case let x where x.hasPrefix("BAT") || x.hasPrefix("CGN"):
            return teal
        case let x where x.hasPrefix("N"):
            return graphite
        default:
            return graphite
        }
    }
}

// LineBadge now accepts an explicit color; defaults to SBBStyle.red so
// existing call sites without a color argument continue to compile.
struct LineBadge: View {
    var text: String
    var color: Color = SBBStyle.red

    var body: some View {
        Text(text.isEmpty ? "?" : text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color, in: RoundedRectangle(cornerRadius: 3))
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS' -only-testing:SBBDeparturesTests/SBBStyleTests 2>&1 | grep -E 'Test.*passed|FAILED|error:'
```

Expected: `Test Suite 'SBBStyleTests' passed`

- [ ] **Step 5: Commit**

```bash
git add SBBDepartures/App/SBBStyle.swift SBBDeparturesTests/SBBStyleTests.swift
git commit -m "feat: add transport-type badge colors and badgeColor(for:) function"
```

---

## Task 2: AppState Helpers

**Files:**
- Modify: `SBBDepartures/App/DeparturesAppState.swift`
- Create: `SBBDeparturesTests/AppStateTests.swift`

**Interfaces:**
- Consumes: existing `DeparturesAppState`, `FavoriteTransport`, `TransitStop`, `StationboardDeparture`
- Produces: `appState.hasFavorite(stopId: String, category: String, number: String, destination: String) -> Bool`
- Produces: `appState.addProfile(mode: LocationProfile.Mode = .manual)` — replaces `addProfile()`
- Produces: `DepartureLogic.normalize(_:)` — changed from `private` to `internal`

- [ ] **Step 1: Write failing tests**

Create `SBBDeparturesTests/AppStateTests.swift`:

```swift
import XCTest

final class AppStateTests: XCTestCase {
    func test_hasFavorite_returnsFalseWhenEmpty() {
        let appState = DeparturesAppState()
        XCTAssertFalse(appState.hasFavorite(stopId: "8503000", category: "IC", number: "5", destination: "Bern"))
    }

    func test_hasFavorite_returnsTrueAfterAdding() {
        let appState = DeparturesAppState()
        let stop = TransitStop(id: "8503000", name: "Zürich HB", coordinate: nil, distance: nil)
        let departure = StationboardDeparture(
            id: "1", category: "IC", number: "5", destination: "Bern",
            plannedDeparture: Date(), realtimeDeparture: nil, platform: nil, delayMinutes: nil
        )
        appState.addFavorite(stop: stop, departure: departure)
        XCTAssertTrue(appState.hasFavorite(stopId: "8503000", category: "IC", number: "5", destination: "Bern"))
    }

    func test_hasFavorite_isCaseAndDiacriticInsensitive() {
        let appState = DeparturesAppState()
        let stop = TransitStop(id: "8503000", name: "Zürich HB", coordinate: nil, distance: nil)
        let departure = StationboardDeparture(
            id: "1", category: "IC", number: "5", destination: "Bern",
            plannedDeparture: Date(), realtimeDeparture: nil, platform: nil, delayMinutes: nil
        )
        appState.addFavorite(stop: stop, departure: departure)
        XCTAssertTrue(appState.hasFavorite(stopId: "8503000", category: "ic", number: "5", destination: "bern"))
    }

    func test_hasFavorite_onlyMatchesActiveProfile() {
        let appState = DeparturesAppState()
        let profileAId = appState.state.activeProfileId
        let stop = TransitStop(id: "8503000", name: "Zürich HB", coordinate: nil, distance: nil)
        let departure = StationboardDeparture(
            id: "1", category: "IC", number: "5", destination: "Bern",
            plannedDeparture: Date(), realtimeDeparture: nil, platform: nil, delayMinutes: nil
        )
        appState.addFavorite(stop: stop, departure: departure)

        // Switch to a different profile
        appState.addProfile()
        XCTAssertNotEqual(appState.state.activeProfileId, profileAId)
        XCTAssertFalse(appState.hasFavorite(stopId: "8503000", category: "IC", number: "5", destination: "Bern"))
    }

    func test_addProfile_withAutomaticMode() {
        let appState = DeparturesAppState()
        let before = appState.state.profiles.count
        appState.addProfile(mode: .automatic)
        XCTAssertEqual(appState.state.profiles.count, before + 1)
        XCTAssertEqual(appState.activeProfile?.mode, .automatic)
        XCTAssertEqual(appState.activeProfile?.emoji, "📍")
    }
}
```

- [ ] **Step 2: Run tests — confirm they fail**

```bash
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS' -only-testing:SBBDeparturesTests/AppStateTests 2>&1 | grep -E 'error:|FAILED|hasFavorite'
```

Expected: compile error — `hasFavorite` and updated `addProfile` do not exist.

- [ ] **Step 3: Modify DeparturesAppState.swift**

Open `SBBDepartures/App/DeparturesAppState.swift`.

**3a — Change `addProfile()` to accept a mode parameter** (around line 93):

```swift
// Replace:
func addProfile() {
    let profile = LocationProfile(
        id: UUID(),
        name: "New profile",
        coordinate: nil,
        radiusMeters: nil,
        mode: .manual,
        emoji: "⭐️",
        colorHex: nil
    )
    state.profiles.append(profile)
    state.activeProfileId = profile.id
    persist()
}

// With:
func addProfile(mode: LocationProfile.Mode = .manual) {
    let profile = LocationProfile(
        id: UUID(),
        name: mode == .automatic ? "Nearby" : "New profile",
        coordinate: nil,
        radiusMeters: mode == .automatic ? 600 : nil,
        mode: mode,
        emoji: mode == .automatic ? "📍" : "⭐️",
        colorHex: nil
    )
    state.profiles.append(profile)
    state.activeProfileId = profile.id
    persist()
}
```

**3b — Add `hasFavorite` helper** (add after `removeFavorites(ids:)`, around line 186):

```swift
func hasFavorite(stopId: String, category: String, number: String, destination: String) -> Bool {
    state.favorites.contains { f in
        f.profileId == state.activeProfileId
            && f.stopId == stopId
            && DepartureLogic.normalize(f.lineCategory) == DepartureLogic.normalize(category)
            && DepartureLogic.normalize(f.lineNumber) == DepartureLogic.normalize(number)
            && DepartureLogic.normalize(f.directionName) == DepartureLogic.normalize(destination)
    }
}
```

**3c — Make `DepartureLogic.normalize` internal** in `Models.swift` (line 174):

```swift
// Replace:
private static func normalize(_ value: String) -> String {

// With:
static func normalize(_ value: String) -> String {
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS' -only-testing:SBBDeparturesTests/AppStateTests 2>&1 | grep -E 'Test.*passed|FAILED|error:'
```

Expected: `Test Suite 'AppStateTests' passed`

- [ ] **Step 5: Run all tests to check no regressions**

```bash
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'Test Suite.*passed|FAILED|error:'
```

Expected: all suites pass.

- [ ] **Step 6: Commit**

```bash
git add SBBDepartures/App/DeparturesAppState.swift SBBDepartures/Shared/Models.swift SBBDeparturesTests/AppStateTests.swift
git commit -m "feat: add hasFavorite helper and addProfile(mode:) for location watchlist creation"
```

---

## Task 3: MenuBarPopoverView Rewrite

**Files:**
- Modify (full rewrite): `SBBDepartures/App/MenuBarPopoverView.swift`

**Interfaces:**
- Consumes: `SBBStyle.badgeColor(for:)` (Task 1), `appState.nearbySnapshots`, `appState.locationAuthorization`, `appState.addProfile(mode:)` (Task 2)
- Consumes: `@Environment(\.openWindow)` — requires window ID `"management"` to exist (wired in Task 7; compile fine until then, crash if used before Task 7)
- Produces: `MenuBarPopoverView` (replaces existing), `QuickDepartureRow`

- [ ] **Step 1: Rewrite MenuBarPopoverView.swift**

Replace the entire contents of `SBBDepartures/App/MenuBarPopoverView.swift`:

```swift
import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @Environment(\.openWindow) private var openWindow

    private var locationProfile: LocationProfile? {
        appState.state.profiles.first { $0.mode == .automatic }
    }

    // 1 row per unique line/direction — the soonest departure from nearbySnapshots.
    private var quickViewRows: [DepartureSnapshot] {
        var seen = Set<String>()
        return appState.nearbySnapshots
            .filter { $0.effectiveDeparture >= Date().addingTimeInterval(-60) }
            .sorted { $0.effectiveDeparture < $1.effectiveDeparture }
            .filter { seen.insert("\($0.lineDisplay)-\($0.destination)").inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 420)
        .onAppear {
            if locationProfile != nil {
                Task { await appState.refreshNearbyDepartures() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .foregroundStyle(SBBStyle.red)
                .font(.caption)
            Text(locationProfile?.name ?? "Quick View")
                .font(.headline)
            Spacer()
            if appState.isRefreshing || appState.isRefreshingNearby {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await appState.refreshNearbyDepartures() }
                } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh departures")
            }
            if let last = appState.state.lastRefresh {
                Text(DepartureDateFormatting.relativeFormatter.localizedString(for: last, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundStyle(
                        DepartureLogic.isStale(lastRefresh: appState.state.lastRefresh)
                            ? Color(hex: SBBPalette.orangeHex)
                            : .secondary
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if appState.locationAuthorization == .denied || appState.locationAuthorization == .restricted {
            noPermissionView
        } else if locationProfile == nil {
            noProfileView
        } else {
            departuresList
        }
    }

    private var noPermissionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Location access needed")
                .font(.subheadline.weight(.semibold))
            Button("Allow Location Access") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .accessibilityElement(children: .combine)
    }

    private var noProfileView: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No location watchlist set up")
                .font(.subheadline.weight(.semibold))
            Button("Create Nearby Watchlist →") {
                appState.addProfile(mode: .automatic)
                openWindow(id: "management")
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var departuresList: some View {
        if quickViewRows.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tram").foregroundStyle(.secondary)
                Text("No upcoming departures")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(quickViewRows.enumerated()), id: \.element.id) { index, snapshot in
                    QuickDepartureRow(snapshot: snapshot)
                    if index < quickViewRows.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Open") { openWindow(id: "management") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Open management window")
            Spacer()
            Button {
                openWindow(id: "management")
            } label: {
                Label("Manage", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Manage watchlists")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct QuickDepartureRow: View {
    var snapshot: DepartureSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Text("\(DepartureLogic.minutesUntil(snapshot.effectiveDeparture))′")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(SBBStyle.red)
                .frame(width: 46, alignment: .trailing)

            LineBadge(
                text: snapshot.lineDisplay,
                color: SBBStyle.badgeColor(for: snapshot.lineDisplay)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("→ \(snapshot.destination)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(snapshot.stopName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let delay = snapshot.delayMinutes, delay > 0 {
                        Text("+\(delay)′")
                            .font(.caption)
                            .foregroundStyle(SBBStyle.redDark)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DepartureDateFormatting.timeFormatter.string(from: snapshot.effectiveDeparture))
                    .font(.subheadline.monospacedDigit())
                if let platform = snapshot.platform, !platform.isEmpty {
                    Text(platform)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [
            "\(snapshot.lineDisplay) to \(snapshot.destination)",
            "in \(DepartureLogic.minutesUntil(snapshot.effectiveDeparture)) minutes",
            "from \(snapshot.stopName)"
        ]
        if let delay = snapshot.delayMinutes, delay > 0 { parts.append("\(delay) minutes delayed") }
        return parts.joined(separator: ", ")
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED` (openWindow ID "management" doesn't exist yet but will compile fine — the environment value is resolved at runtime).

- [ ] **Step 3: Commit**

```bash
git add SBBDepartures/App/MenuBarPopoverView.swift
git commit -m "feat: rewrite MenuBarPopoverView as quick-glance surface with 1 departure per line"
```

---

## Task 4: ManagementWindowView

**Files:**
- Create: `SBBDepartures/App/ManagementWindowView.swift`

**Interfaces:**
- Consumes: `SBBStyle.badgeColor(for:)` (Task 1), `appState.dashboardSnapshots`, `appState.state.profiles`, `appState.deleteProfile(_:)`, `appState.addProfile(mode:)` (Task 2)
- Produces: `ManagementWindowView`, `ProfileDetailHeader`, `ProfileEditorPopover`, `DepartureBoardSection`, `DepartureBoardRow`, `SidebarProfileRow`
- Note: references `WatchedLinesSection` (Task 5) — add placeholder stub so it compiles now

- [ ] **Step 1: Create ManagementWindowView.swift**

Create `SBBDepartures/App/ManagementWindowView.swift`:

```swift
import SwiftUI

struct ManagementWindowView: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var deletingProfile: LocationProfile?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 780, minHeight: 540)
        .confirmationDialog(
            "Delete \"\(deletingProfile?.name ?? "")\"?",
            isPresented: Binding(
                get: { deletingProfile != nil },
                set: { if !$0 { deletingProfile = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = deletingProfile { appState.deleteProfile(p) }
                deletingProfile = nil
            }
            Button("Cancel", role: .cancel) { deletingProfile = nil }
        } message: {
            if let p = deletingProfile {
                let count = appState.state.favorites.filter { $0.profileId == p.id }.count
                Text("This removes \(count) saved line\(count == 1 ? "" : "s") and all departure data.")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: activeProfileSelection) {
            Section("Watchlists") {
                ForEach(appState.state.profiles) { profile in
                    SidebarProfileRow(profile: profile)
                        .tag(profile.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deletingProfile = profile
                            }
                            .disabled(appState.state.profiles.count <= 1)
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                appState.addProfile()
            } label: {
                Label("New Watchlist", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(12)
            .accessibilityLabel("New watchlist")
        }
        .navigationTitle("Watchlists")
        .frame(minWidth: 180)
    }

    private var activeProfileSelection: Binding<UUID?> {
        Binding(
            get: { appState.state.activeProfileId },
            set: { id in
                guard let id, let profile = appState.state.profiles.first(where: { $0.id == id }) else { return }
                appState.setActiveProfile(profile)
            }
        )
    }

    // MARK: - Detail

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProfileDetailHeader(onDeleteProfile: {
                    deletingProfile = appState.activeProfile
                })
                DepartureBoardSection()
                WatchedLinesSection()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SBBStyle.milk)
        .navigationTitle(appState.activeProfile?.name ?? "Watchlist")
    }
}

// MARK: - SidebarProfileRow

struct SidebarProfileRow: View {
    @EnvironmentObject private var appState: DeparturesAppState
    var profile: LocationProfile

    var body: some View {
        HStack(spacing: 10) {
            Text(profile.displayEmoji)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).lineLimit(1)
                Text(profile.mode == .automatic
                     ? "Current location"
                     : "\(appState.state.favorites.filter { $0.profileId == profile.id }.count) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ProfileDetailHeader

struct ProfileDetailHeader: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var showingEditor = false
    var onDeleteProfile: () -> Void

    var body: some View {
        HStack {
            Text("\(appState.activeProfile?.displayEmoji ?? "🚆") \(appState.activeProfile?.name ?? "Watchlist")")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(SBBStyle.graphite)
            Spacer()
            Button {
                showingEditor = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit watchlist")
            .popover(isPresented: $showingEditor, arrowEdge: .top) {
                if let binding = profileBinding {
                    ProfileEditorPopover(
                        profile: binding,
                        canDelete: appState.state.profiles.count > 1,
                        onDelete: {
                            showingEditor = false
                            onDeleteProfile()
                        }
                    )
                }
            }
        }
    }

    private var profileBinding: Binding<LocationProfile>? {
        guard let profile = appState.activeProfile else { return nil }
        return Binding(
            get: { appState.state.profiles.first(where: { $0.id == profile.id }) ?? profile },
            set: { appState.updateProfile($0) }
        )
    }
}

// MARK: - ProfileEditorPopover

struct ProfileEditorPopover: View {
    @Binding var profile: LocationProfile
    var canDelete: Bool
    var onDelete: () -> Void

    private let emojiChoices = ["🏠", "💼", "📍", "🚆", "⭐️", "🎒", "☕️", "🏫"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Watchlist name", text: $profile.name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                ForEach(emojiChoices, id: \.self) { emoji in
                    Button {
                        profile.emoji = emoji
                    } label: {
                        Text(emoji)
                            .font(.title3)
                            .frame(width: 34, height: 30)
                            .background(
                                profile.displayEmoji == emoji ? SBBStyle.cloud : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(emoji) icon")
                }
            }

            Picker("Mode", selection: $profile.mode) {
                Text("Manual").tag(LocationProfile.Mode.manual)
                Text("Auto (location)").tag(LocationProfile.Mode.automatic)
            }
            .pickerStyle(.segmented)

            Divider()

            Button("Delete Watchlist", role: .destructive, action: onDelete)
                .disabled(!canDelete)
                .accessibilityLabel("Delete this watchlist")
        }
        .padding(16)
        .frame(width: 280)
    }
}

// MARK: - DepartureBoardSection

struct DepartureBoardSection: View {
    @EnvironmentObject private var appState: DeparturesAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NEXT DEPARTURES")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if appState.isRefreshing || appState.isRefreshingNearby {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task {
                            if appState.activeProfile?.mode == .automatic {
                                await appState.refreshNearbyDepartures()
                            } else {
                                await appState.refreshNow()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh departures")
                }
            }

            if let error = appState.state.lastErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(SBBStyle.redDark)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
            }

            if appState.dashboardSnapshots.isEmpty {
                Text("No departures — add a watched line below.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.dashboardSnapshots.prefix(12).enumerated()), id: \.element.id) { index, snapshot in
                        DepartureBoardRow(snapshot: snapshot)
                        if index < min(appState.dashboardSnapshots.count, 12) - 1 {
                            Divider()
                        }
                    }
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
            }
        }
    }
}

struct DepartureBoardRow: View {
    var snapshot: DepartureSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Text("\(DepartureLogic.minutesUntil(snapshot.effectiveDeparture))′")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(SBBStyle.red)
                .frame(width: 50, alignment: .trailing)

            LineBadge(
                text: snapshot.lineDisplay,
                color: SBBStyle.badgeColor(for: snapshot.lineDisplay)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.destination)
                    .font(.headline)
                    .foregroundStyle(SBBStyle.graphite)
                if let delay = snapshot.delayMinutes, delay > 0 {
                    Text("+\(delay) min")
                        .font(.caption)
                        .foregroundStyle(SBBStyle.redDark)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DepartureDateFormatting.timeFormatter.string(from: snapshot.effectiveDeparture))
                    .font(.headline.monospacedDigit())
                if let platform = snapshot.platform, !platform.isEmpty {
                    Text("Pl. \(platform)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.lineDisplay) to \(snapshot.destination) in \(DepartureLogic.minutesUntil(snapshot.effectiveDeparture)) minutes")
    }
}
```

- [ ] **Step 2: Add WatchedLinesSection stub so the file compiles**

Append to the end of `ManagementWindowView.swift`:

```swift
// MARK: - WatchedLinesSection stub (replaced in Task 5)
struct WatchedLinesSection: View {
    var body: some View { EmptyView() }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add SBBDepartures/App/ManagementWindowView.swift
git commit -m "feat: add ManagementWindowView with sidebar, profile editor, and departure board"
```

---

## Task 5: WatchedLinesSection and AddLinePanel

**Files:**
- Create: `SBBDepartures/App/WatchedLinesSection.swift`
- Modify: `SBBDepartures/App/ManagementWindowView.swift` — remove stub

**Interfaces:**
- Consumes: `appState.activeFavorites`, `appState.hasFavorite(stopId:category:number:destination:)` (Task 2), `appState.searchResults`, `appState.candidateDepartures`, `SBBStyle.badgeColor(for:)` (Task 1)
- Produces: `WatchedLinesSection`, `WatchedLineRow`, `AddLinePanel`, `CandidateLineRow`, `StopPickerRow`

- [ ] **Step 1: Create WatchedLinesSection.swift**

Create `SBBDepartures/App/WatchedLinesSection.swift`:

```swift
import SwiftUI

// MARK: - WatchedLinesSection

struct WatchedLinesSection: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var expandedId: UUID?
    @State private var showingAddPanel = false
    @State private var deletingFavorite: FavoriteTransport?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader
            favoritesList
            if showingAddPanel {
                AddLinePanel(onClose: { showingAddPanel = false })
            }
        }
        .confirmationDialog(
            "Remove \(deletingFavorite.map { "\($0.displayLine) → \($0.directionName)" } ?? "")?",
            isPresented: Binding(
                get: { deletingFavorite != nil },
                set: { if !$0 { deletingFavorite = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let f = deletingFavorite { appState.removeFavorite(f) }
                deletingFavorite = nil
            }
            Button("Cancel", role: .cancel) { deletingFavorite = nil }
        } message: {
            Text("This will stop showing this departure.")
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("WATCHED LINES")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text("\(appState.activeFavorites.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(SBBStyle.red, in: Capsule())
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingAddPanel.toggle()
                }
            } label: {
                Label(showingAddPanel ? "Close" : "+ Add", systemImage: showingAddPanel ? "xmark" : "plus")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(showingAddPanel ? "Close add panel" : "Add a line")
        }
    }

    @ViewBuilder
    private var favoritesList: some View {
        if appState.activeFavorites.isEmpty {
            Text("No lines saved. Tap \"+ Add\" to search for a stop and pick a line.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 70)
                .multilineTextAlignment(.center)
                .padding()
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
        } else {
            VStack(spacing: 6) {
                ForEach(appState.activeFavorites) { favorite in
                    WatchedLineRow(
                        favorite: favorite,
                        isExpanded: expandedId == favorite.id,
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                expandedId = expandedId == favorite.id ? nil : favorite.id
                            }
                        },
                        onDelete: { deletingFavorite = favorite }
                    )
                }
            }
        }
    }
}

// MARK: - WatchedLineRow

struct WatchedLineRow: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State var favorite: FavoriteTransport
    var isExpanded: Bool
    var onToggleExpand: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if isExpanded {
                Divider()
                expandedRow
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
    }

    private var mainRow: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { favorite.enabled },
                set: { v in favorite.enabled = v; appState.updateFavorite(favorite) }
            ))
            .labelsHidden()
            .tint(SBBStyle.red)
            .accessibilityLabel(favorite.enabled ? "Disable \(favorite.displayLine)" : "Enable \(favorite.displayLine)")

            LineBadge(
                text: favorite.displayLine,
                color: SBBStyle.badgeColor(for: favorite.lineCategory)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("→ \(favorite.directionName)")
                    .font(.headline)
                    .lineLimit(1)
                Text(favorite.stopName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onToggleExpand) {
                Image(systemName: isExpanded ? "chevron.up" : "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse options" : "Show options")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var expandedRow: some View {
        HStack(spacing: 20) {
            walkField
            alertField
            Spacer()
            Button("Remove", role: .destructive, action: onDelete)
                .font(.caption)
                .accessibilityLabel("Remove \(favorite.displayLine) → \(favorite.directionName)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SBBStyle.milk)
    }

    private var walkField: some View {
        HStack(spacing: 6) {
            Text("Walk")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", value: Binding(
                get: { favorite.walkMinutes ?? 0 },
                set: { v in
                    favorite.walkMinutes = v == 0 ? nil : v
                    appState.updateFavorite(favorite)
                }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 48)
            Text("min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var alertField: some View {
        HStack(spacing: 6) {
            Toggle("Alert", isOn: Binding(
                get: { favorite.alerts.enabled },
                set: { v in favorite.alerts.enabled = v; appState.updateFavorite(favorite) }
            ))
            .font(.caption)
            .tint(SBBStyle.red)
            if favorite.alerts.enabled {
                TextField("7", value: Binding(
                    get: { favorite.alerts.leadMinutes },
                    set: { v in favorite.alerts.leadMinutes = v; appState.updateFavorite(favorite) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 48)
                Text("min before")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - AddLinePanel

private enum AddLineSource: String, CaseIterable, Identifiable {
    case search, nearby
    var id: String { rawValue }
    var label: String { self == .search ? "Search stop" : "Near me" }
    var icon: String { self == .search ? "magnifyingglass" : "location" }
}

struct AddLinePanel: View {
    @EnvironmentObject private var appState: DeparturesAppState
    @State private var source: AddLineSource = .search
    @State private var selectedStop: TransitStop?
    @State private var recentlyAdded: Set<String> = []
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelHeader
            sourcePicker
            if source == .search { searchField }
            columns
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(SBBStyle.cloud) }
        .onDisappear {
            appState.searchQuery = ""
        }
    }

    private var panelHeader: some View {
        HStack {
            Text("ADD A LINE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close add panel")
        }
    }

    private var sourcePicker: some View {
        Picker("Source", selection: $source) {
            ForEach(AddLineSource.allCases) { s in
                Label(s.label, systemImage: s.icon).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: source) { _, newValue in
            selectedStop = nil
            appState.searchQuery = ""
            if newValue == .nearby {
                Task { await appState.requestLocationAndLoadNearby() }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            TextField("Stop name, e.g. Zürich HB", text: $appState.searchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    selectedStop = nil
                    Task { await appState.searchStops() }
                }
            Button("Search") {
                selectedStop = nil
                Task { await appState.searchStops() }
            }
            .buttonStyle(.borderedProminent)
            .tint(SBBStyle.red)
        }
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 14) {
            stopColumn
            lineColumn
        }
        .frame(minHeight: 180)
    }

    private var stopColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("① STOP")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if appState.searchResults.isEmpty {
                columnHint(source == .search
                    ? "Search a stop name to begin."
                    : "Loading nearby stops…")
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.searchResults) { stop in
                            StopPickerRow(stop: stop, isSelected: selectedStop?.id == stop.id)
                                .onTapGesture {
                                    selectedStop = stop
                                    Task { await appState.loadCandidates(for: stop) }
                                }
                                .accessibilityAddTraits(selectedStop?.id == stop.id ? .isSelected : [])
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 200)
                .background(SBBStyle.milk, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(minWidth: 180, maxWidth: 260)
    }

    private var lineColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedStop == nil
                 ? "② LINE / DIRECTION"
                 : "② FROM \(selectedStop!.name.uppercased())")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if selectedStop == nil {
                columnHint("Select a stop to see lines.")
            } else if appState.candidateDepartures.isEmpty {
                columnHint("Loading lines…")
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.candidateDepartures) { departure in
                            let key = "\(departure.category)-\(departure.number)-\(departure.destination)"
                            let saved = selectedStop.map {
                                appState.hasFavorite(
                                    stopId: $0.id,
                                    category: departure.category,
                                    number: departure.number,
                                    destination: departure.destination
                                )
                            } ?? false

                            CandidateLineRow(
                                departure: departure,
                                alreadySaved: saved,
                                justAdded: recentlyAdded.contains(key)
                            ) {
                                guard let stop = selectedStop else { return }
                                appState.addFavorite(stop: stop, departure: departure)
                                recentlyAdded.insert(key)
                                Task {
                                    try? await Task.sleep(for: .seconds(1.5))
                                    recentlyAdded.remove(key)
                                }
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 200)
                .background(SBBStyle.milk, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func columnHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
            .multilineTextAlignment(.center)
            .padding(8)
            .background(SBBStyle.milk, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - StopPickerRow

struct StopPickerRow: View {
    var stop: TransitStop
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "mappin.circle")
                .foregroundStyle(isSelected ? SBBStyle.red : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SBBStyle.graphite)
                    .lineLimit(1)
                if let distance = stop.distance {
                    Text("\(Int(distance)) m away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(isSelected ? .white : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? SBBStyle.red : Color.clear)
        }
    }
}

// MARK: - CandidateLineRow

struct CandidateLineRow: View {
    var departure: StationboardDeparture
    var alreadySaved: Bool
    var justAdded: Bool
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            LineBadge(
                text: departure.lineDisplay,
                color: SBBStyle.badgeColor(for: departure.category)
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("→ \(departure.destination)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(alreadySaved ? .secondary : SBBStyle.graphite)
                    .lineLimit(1)
                Text(DepartureDateFormatting.timeFormatter.string(
                    from: departure.realtimeDeparture ?? departure.plannedDeparture))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if alreadySaved {
                Text("already saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if justAdded {
                Label("Added", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SBBStyle.green)
            } else {
                Button("+ Add", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .tint(SBBStyle.red)
                    .controlSize(.small)
                    .accessibilityLabel("Add \(departure.lineDisplay) to \(departure.destination)")
            }
        }
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 6))
        .opacity(alreadySaved ? 0.6 : 1.0)
    }
}
```

- [ ] **Step 2: Remove the WatchedLinesSection stub from ManagementWindowView.swift**

Delete these lines from the bottom of `ManagementWindowView.swift`:

```swift
// MARK: - WatchedLinesSection stub (replaced in Task 5)
struct WatchedLinesSection: View {
    var body: some View { EmptyView() }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add SBBDepartures/App/WatchedLinesSection.swift SBBDepartures/App/ManagementWindowView.swift
git commit -m "feat: add WatchedLinesSection with expandable rows, Add Line panel, and duplicate prevention"
```

---

## Task 6: App Wiring

**Files:**
- Modify: `SBBDepartures/App/SBBDeparturesApp.swift`
- Delete: `SBBDepartures/App/DashboardView.swift`
- Delete: `SBBDepartures/App/SettingsView.swift`

**Interfaces:**
- Consumes: `ManagementWindowView` (Task 4), `MenuBarPopoverView` (Task 3)
- Window ID `"management"` wired here — resolves the `openWindow(id:)` calls in the popover

- [ ] **Step 1: Rewrite SBBDeparturesApp.swift**

Replace the entire contents of `SBBDepartures/App/SBBDeparturesApp.swift`:

```swift
import SwiftUI

@main
struct SBBDeparturesApp: App {
    @StateObject private var appState = DeparturesAppState()

    var body: some Scene {
        WindowGroup(id: "management") {
            ManagementWindowView()
                .environmentObject(appState)
        }
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(appState)
                .frame(width: 420)
        } label: {
            Label(appState.menuBarTitle, systemImage: "tram.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: Delete old files**

```bash
rm SBBDepartures/App/DashboardView.swift
rm SBBDepartures/App/SettingsView.swift
```

- [ ] **Step 3: Build — verify no references remain**

```bash
xcodebuild build -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED`. If there are "use of undeclared type" errors, grep for remaining usages:

```bash
grep -rn "ManageSheetView\|DashboardView\|SettingsView\|SBBBrandHeader\|WatchlistSection\|FavoriteEditorRow\|AddFavoritePanel\|CandidateDepartureRow\|WatchlistSelectorRow\|DashboardDepartureRow\|DashboardHeaderRow\|ProfileEditor[^P]" SBBDepartures/
```

Remove any remaining usages found.

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'Test Suite.*passed|FAILED|error:'
```

Expected: all suites pass.

- [ ] **Step 5: Commit**

```bash
git add SBBDepartures/App/SBBDeparturesApp.swift
git rm SBBDepartures/App/DashboardView.swift SBBDepartures/App/SettingsView.swift
git commit -m "feat: wire up Management Window as primary window, remove old dashboard and settings views"
```

---

## Task 7: Widget Color Fixes

**Files:**
- Modify: `SBBDepartures/Widget/DeparturesWidget.swift`

**Interfaces:**
- Consumes: `SBBStyle.badgeColor(for:)` (Task 1)

- [ ] **Step 1: Apply badgeColor to WidgetDepartureRow and fix delay color**

In `SBBDepartures/Widget/DeparturesWidget.swift`, find `WidgetDepartureRow` (around line 78). Make two targeted edits:

**Edit 1** — add `LineBadge` with proper color (replace plain text line display):

```swift
// Replace:
HStack(spacing: 4) {
    Text(snapshot.lineDisplay)
        .font(.subheadline.weight(.semibold))
    Text(snapshot.destination)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
}

// With:
HStack(spacing: 4) {
    LineBadge(
        text: snapshot.lineDisplay,
        color: SBBStyle.badgeColor(for: snapshot.lineDisplay)
    )
    Text(snapshot.destination)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
}
```

**Edit 2** — fix delay color (around line 99):

```swift
// Replace:
Text("+\(delay)").foregroundStyle(.red)

// With:
Text("+\(delay)").foregroundStyle(SBBStyle.redDark)
```

- [ ] **Step 2: Build widget target**

```bash
xcodebuild build -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add SBBDepartures/Widget/DeparturesWidget.swift
git commit -m "fix: apply transport-type badge colors and consistent delay color to widget"
```

---

## Task 8: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme SBBDepartures -destination 'platform=macOS' 2>&1 | grep -E 'Test Suite.*passed|FAILED|error:'
```

Expected: all suites pass, no errors.

- [ ] **Step 2: Verify no stray references to removed types**

```bash
grep -rn "SBBBrandHeader\|ManageSheetView\|DashboardView\|openSettings" SBBDepartures/ && echo "FOUND STRAY REFS" || echo "CLEAN"
```

Expected: `CLEAN`

- [ ] **Step 3: Verify delay and stale colors use palette, not system colors**

```bash
grep -rn "\.foregroundStyle(\.red)\|\.foregroundStyle(\.orange)" SBBDepartures/ | grep -v "\.role"
```

Expected: no output (all semantic reds/oranges should now be `SBBStyle.redDark` or `Color(hex: SBBPalette.orangeHex)`).

- [ ] **Step 4: Build release**

```bash
xcodebuild build -scheme SBBDepartures -configuration Release -destination 'platform=macOS' 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: final verification pass — UX redesign complete"
```

---

## Summary

| Task | Deliverable | Tests |
|---|---|---|
| 1 | Color system + badgeColor | SBBStyleTests (9 tests) |
| 2 | hasFavorite + addProfile(mode:) | AppStateTests (4 tests) |
| 3 | MenuBarPopoverView quick view | Build verification |
| 4 | ManagementWindowView scaffold | Build verification |
| 5 | WatchedLinesSection + AddLinePanel | Build verification |
| 6 | App wiring + delete old files | Full test suite |
| 7 | Widget color fixes | Build verification |
| 8 | Final verification | Full test suite + grep checks |
