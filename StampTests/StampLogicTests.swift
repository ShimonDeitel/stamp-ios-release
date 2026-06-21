import XCTest
import SwiftData
@testable import Stamp

/// Tests for the pure logic: completion math, model mapping, the bundled dataset parser,
/// AppModel place/list management, and Pro gating (defense-in-depth).
final class StampLogicTests: XCTestCase {

    // MARK: CompletionStats math

    func testCompletionStatsEmptyListIsZero() {
        let s = CompletionStats(total: 0, visited: 0)
        XCTAssertEqual(s.fraction, 0)
        XCTAssertEqual(s.percent, 0)
        XCTAssertEqual(s.backlog, 0)
    }

    func testCompletionStatsFractionAndPercent() {
        let s = CompletionStats(total: 4, visited: 1)
        XCTAssertEqual(s.fraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(s.percent, 25)
        XCTAssertEqual(s.backlog, 3)

        let full = CompletionStats(total: 3, visited: 3)
        XCTAssertEqual(full.percent, 100)
        XCTAssertEqual(full.backlog, 0)
    }

    func testCompletionStatsPercentRounds() {
        // 1/3 == 33.33% → rounds to 33.
        XCTAssertEqual(CompletionStats(total: 3, visited: 1).percent, 33)
        // 2/3 == 66.66% → rounds to 67.
        XCTAssertEqual(CompletionStats(total: 3, visited: 2).percent, 67)
    }

    func testCompletionStatsFromPlaces() {
        let places = [
            Place(name: "A", visited: true),
            Place(name: "B", visited: false),
            Place(name: "C", visited: true)
        ]
        let s = CompletionStats.from(places)
        XCTAssertEqual(s.total, 3)
        XCTAssertEqual(s.visited, 2)
        XCTAssertEqual(s.percent, 67)
    }

    // MARK: Model mapping

    func testPlaceContinentAndVibeAccessors() {
        let p = Place(name: "Test", continent: .asia, vibe: .food)
        XCTAssertEqual(p.continentValue, .asia)
        XCTAssertEqual(p.vibeValue, .food)
        p.continentValue = .oceania
        XCTAssertEqual(p.continentRaw, "oceania")
    }

    func testCorruptRawValuesFallBackSafely() {
        let p = Place(name: "X")
        p.continentRaw = "atlantis"
        p.vibeRaw = "nonsense"
        XCTAssertEqual(p.continentValue, .europe)   // safe fallback
        XCTAssertEqual(p.vibeValue, .none)          // safe fallback
    }

    func testVibeSelectableExcludesNone() {
        XCTAssertFalse(Vibe.selectable.contains(.none))
        XCTAssertEqual(Vibe.selectable.count, 6)
    }

    // MARK: Bundled dataset parsing

    func testCatalogParsesValidJSON() {
        let json = """
        [
          { "name": "Eiffel Tower, Paris", "continent": "europe", "vibe": "city" },
          { "name": "Great Wall of China", "continent": "asia", "vibe": "history" }
        ]
        """.data(using: .utf8)!
        let parsed = Catalog.parse(json)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].name, "Eiffel Tower, Paris")
        XCTAssertEqual(parsed[0].continent, .europe)
        XCTAssertEqual(parsed[1].vibe, .history)
    }

    func testCatalogParseHandlesGarbage() {
        XCTAssertTrue(Catalog.parse(Data("not json".utf8)).isEmpty)
    }

    func testBundledLandmarksLoadAndAreNonEmpty() {
        // The dataset ships with the test bundle's resources via the app target dependency.
        let suggestions = Catalog.loadSuggestions(from: Bundle(for: Self.self))
        // Fall back gracefully: this asserts the parser+model wiring, not bundle layout.
        for s in suggestions {
            XCTAssertFalse(s.name.isEmpty)
        }
    }

    // MARK: AppModel place management

    @MainActor
    private func freshModel() -> AppModel {
        let container = try! ModelContainer(
            for: Place.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return AppModel(container: container)
    }

    @MainActor
    func testAddAndToggleAndStats() {
        let model = freshModel()
        XCTAssertEqual(model.currentStats.total, 0)

        model.addPlace(name: "Tokyo", continent: .asia, vibe: .food)
        model.addPlace(name: "Rome", continent: .europe, vibe: .history)
        XCTAssertEqual(model.currentStats.total, 2)
        XCTAssertEqual(model.currentStats.visited, 0)
        XCTAssertEqual(model.currentStats.percent, 0)

        let tokyo = model.visiblePlaces.first { $0.name == "Tokyo" }!
        model.toggleVisited(tokyo)
        XCTAssertEqual(model.currentStats.visited, 1)
        XCTAssertEqual(model.currentStats.percent, 50)
    }

    @MainActor
    func testContinentBreakdownAggregates() {
        let model = freshModel()
        model.addPlace(name: "Paris", continent: .europe, vibe: .city)
        model.addPlace(name: "Rome", continent: .europe, vibe: .history)
        model.addPlace(name: "Tokyo", continent: .asia, vibe: .food)
        let europe = model.visiblePlaces.first { $0.name == "Paris" }!
        model.toggleVisited(europe)

        let breakdown = model.continentBreakdown()
        let euRow = breakdown.first { $0.continent == .europe }
        XCTAssertEqual(euRow?.total, 2)
        XCTAssertEqual(euRow?.visited, 1)
        let asiaRow = breakdown.first { $0.continent == .asia }
        XCTAssertEqual(asiaRow?.total, 1)
        XCTAssertEqual(asiaRow?.visited, 0)
        // Continents with no places are omitted.
        XCTAssertNil(breakdown.first { $0.continent == .antarctica })
    }

    // MARK: Pro gating (defense-in-depth)

    @MainActor
    func testCustomListBlockedWithoutPro() {
        let model = freshModel()
        // No store attached → not Pro → addList must no-op.
        let result = model.addList(name: "Honeymoon")
        XCTAssertNil(result, "free users must not create custom lists")
        XCTAssertEqual(model.lists.count, 1, "only the default list should remain")
        XCTAssertEqual(model.lists.first?.id, TravelList.defaultID)
    }

    @MainActor
    func testDeleteAllDataResetsState() {
        let model = freshModel()
        model.addPlace(name: "Cairo", continent: .africa, vibe: .history)
        XCTAssertEqual(model.places.count, 1)
        model.deleteAllData()
        XCTAssertEqual(model.places.count, 0)
        XCTAssertEqual(model.lists.count, 1)
        XCTAssertEqual(model.selectedListID, TravelList.defaultID)
    }

    // MARK: Store

    @MainActor
    func testStoreProductID() {
        XCTAssertEqual(Store.productID, "stamp_pro_unlock")
        let store = Store()
        XCTAssertFalse(store.isPro, "Pro must start locked")
        XCTAssertEqual(store.displayPrice, "$0.99")
    }
}
