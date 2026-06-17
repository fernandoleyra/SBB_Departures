import XCTest

final class FixtureTests: XCTestCase {
    func testStationboardDecodingHandlesRealtimeFields() throws {
        let json = """
        {
          "stationboard": [
            {
              "category": "S",
              "number": "2",
              "name": "018279",
              "to": "Ziegelbrücke",
              "stop": {
                "departure": "2026-06-16T20:47:00+0200",
                "platform": "32",
                "delay": 1,
                "prognosis": {
                  "departure": "2026-06-16T20:48:00+0200"
                }
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.transportAPI.decode(StationboardResponse.self, from: json)
        let departure = try XCTUnwrap(StationboardDeparture(apiDeparture: response.stationboard[0]))

        XCTAssertEqual(departure.category, "S")
        XCTAssertEqual(departure.number, "2")
        XCTAssertEqual(departure.destination, "Ziegelbrücke")
        XCTAssertEqual(departure.platform, "32")
        XCTAssertEqual(departure.delayMinutes, 1)
        XCTAssertNotNil(departure.realtimeDeparture)
    }

    func testLocationDecodingDropsNonStationSearchResultsWithoutIds() throws {
        let json = """
        {
          "stations": [
            {"id": null, "name": "Shop", "coordinate": {"type": "WGS84", "x": null, "y": null}},
            {"id": "8503000", "name": "Zürich HB", "coordinate": {"type": "WGS84", "x": 47.377847, "y": 8.540502}}
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LocationsResponse.self, from: json)
        let stops = response.stations.compactMap(TransitStop.init(apiStation:))

        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops[0].id, "8503000")
        XCTAssertEqual(stops[0].coordinate?.latitude, 47.377847)
    }

    func testLegacyProfileDecodingDefaultsVisualFields() throws {
        let profileId = UUID()
        let json = """
        {
          "profiles": [
            {
              "id": "\(profileId.uuidString)",
              "name": "Office",
              "coordinate": null,
              "radiusMeters": null,
              "mode": "manual"
            }
          ],
          "activeProfileId": "\(profileId.uuidString)",
          "favorites": [],
          "snapshots": [],
          "lastRefresh": null,
          "lastErrorMessage": null
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(DeparturesStoreState.self, from: json)

        XCTAssertEqual(state.profiles[0].displayEmoji, "🚆")
        XCTAssertEqual(state.profiles[0].displayColorHex, SBBPalette.redHex)
    }
}
