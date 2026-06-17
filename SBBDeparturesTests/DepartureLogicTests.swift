import XCTest

final class DepartureLogicTests: XCTestCase {
    func testFiltersByStopLineAndDirection() {
        let profileId = UUID()
        let favorite = FavoriteTransport(
            id: UUID(),
            profileId: profileId,
            stopId: "8503000",
            stopName: "Zürich HB",
            lineCategory: "S",
            lineNumber: "2",
            directionName: "Ziegelbrücke",
            enabled: true,
            walkMinutes: nil,
            alerts: .quietDefault
        )
        let planned = Date(timeIntervalSince1970: 1_781_637_600)
        let departures = [
            StationboardDeparture(id: "match", category: "S", number: "2", destination: "Ziegelbrücke", plannedDeparture: planned, realtimeDeparture: nil, platform: "32", delayMinutes: 0),
            StationboardDeparture(id: "wrong-line", category: "S", number: "7", destination: "Winterthur", plannedDeparture: planned, realtimeDeparture: nil, platform: "41", delayMinutes: 0),
            StationboardDeparture(id: "wrong-direction", category: "S", number: "2", destination: "Zürich HB", plannedDeparture: planned, realtimeDeparture: nil, platform: "32", delayMinutes: 0)
        ]

        let snapshots = DepartureLogic.snapshots(for: favorite, departures: departures, fetchedAt: planned)

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].destination, "Ziegelbrücke")
        XCTAssertEqual(snapshots[0].lineDisplay, "S 2")
    }

    func testMultipleFavoritesProduceMultipleOrderedSnapshots() {
        let profileId = UUID()
        let firstFavorite = FavoriteTransport(
            id: UUID(),
            profileId: profileId,
            stopId: "8503000",
            stopName: "Zürich HB",
            lineCategory: "S",
            lineNumber: "2",
            directionName: "Ziegelbrücke",
            enabled: true,
            walkMinutes: nil,
            alerts: .quietDefault
        )
        let secondFavorite = FavoriteTransport(
            id: UUID(),
            profileId: profileId,
            stopId: "8591067",
            stopName: "Zürich, Bahnhofstrasse/HB",
            lineCategory: "T",
            lineNumber: "11",
            directionName: "Rehalp",
            enabled: true,
            walkMinutes: nil,
            alerts: .quietDefault
        )
        let now = Date(timeIntervalSince1970: 1_781_637_000)
        let departures = [
            StationboardDeparture(id: "s2", category: "S", number: "2", destination: "Ziegelbrücke", plannedDeparture: now.addingTimeInterval(600), realtimeDeparture: nil, platform: "32", delayMinutes: 0),
            StationboardDeparture(id: "t11", category: "T", number: "11", destination: "Rehalp", plannedDeparture: now.addingTimeInterval(300), realtimeDeparture: nil, platform: nil, delayMinutes: 0)
        ]

        let snapshots = (
            DepartureLogic.snapshots(for: firstFavorite, departures: departures, fetchedAt: now)
                + DepartureLogic.snapshots(for: secondFavorite, departures: departures, fetchedAt: now)
        ).sorted { $0.effectiveDeparture < $1.effectiveDeparture }

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[0].lineDisplay, "T 11")
        XCTAssertEqual(snapshots[1].lineDisplay, "S 2")
    }

    func testCountdownRoundsUpAndNeverGoesNegative() {
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(DepartureLogic.minutesUntil(Date(timeIntervalSince1970: 101), now: now), 1)
        XCTAssertEqual(DepartureLogic.minutesUntil(Date(timeIntervalSince1970: 220), now: now), 2)
        XCTAssertEqual(DepartureLogic.minutesUntil(Date(timeIntervalSince1970: 50), now: now), 0)
    }

    func testStaleDataThreshold() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(DepartureLogic.isStale(lastRefresh: nil, now: now))
        XCTAssertFalse(DepartureLogic.isStale(lastRefresh: Date(timeIntervalSince1970: 760), now: now))
        XCTAssertTrue(DepartureLogic.isStale(lastRefresh: Date(timeIntervalSince1970: 699), now: now))
    }
}
