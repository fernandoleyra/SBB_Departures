import XCTest

@MainActor
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
