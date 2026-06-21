import Foundation
import SwiftData
import SwiftUI

/// A named bucket list. The default list (id "") is always present and free; additional lists
/// are a Pro feature. Persisted as lightweight metadata in UserDefaults; the places themselves
/// live in SwiftData and reference a list by `listID`.
struct TravelList: Identifiable, Equatable, Codable {
    var id: String
    var name: String

    static let defaultID = ""
    static let defaultList = TravelList(id: defaultID, name: "My Bucket List")
}

/// Pure, view-agnostic completion stats for a set of places. Derived, never stored as truth.
struct CompletionStats: Equatable {
    var total: Int
    var visited: Int

    var backlog: Int { max(0, total - visited) }
    /// 0...1 fraction visited. Empty list reads as 0.
    var fraction: Double { total == 0 ? 0 : Double(visited) / Double(total) }
    var percent: Int { Int((fraction * 100).rounded()) }

    static func from(_ places: [Place]) -> CompletionStats {
        CompletionStats(total: places.count, visited: places.filter { $0.visited }.count)
    }
}

/// App state: owns the SwiftData store, manages lists + places, and derives all stats.
/// Stats are always derived from places — never stored as truth.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var places: [Place] = []
    @Published private(set) var lists: [TravelList] = [TravelList.defaultList]
    @Published var selectedListID: String = TravelList.defaultID

    private let kLists = "stamp.lists"

    init(container: ModelContainer) {
        self.container = container
        loadLists()
        #if DEBUG
        seedIfRequested()
        #endif
        reload()
    }

    // MARK: Container (local-only persistence; no CloudKit / iCloud)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Place.self])
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Places

    func reload() {
        let all = (try? container.mainContext.fetch(
            FetchDescriptor<Place>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )) ?? []
        places = all
        // If the selected list vanished (e.g. deleted), fall back to the default.
        if !lists.contains(where: { $0.id == selectedListID }) {
            selectedListID = TravelList.defaultID
        }
    }

    /// Places in the currently selected list.
    var visiblePlaces: [Place] { places.filter { $0.listID == selectedListID } }

    @discardableResult
    func addPlace(name: String, continent: Continent, vibe: Vibe,
                  listID: String? = nil) -> Place {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = listID ?? selectedListID
        let place = Place(name: trimmed.isEmpty ? "Untitled place" : trimmed,
                          continent: continent, vibe: vibe, visited: false,
                          listID: target)
        let ctx = container.mainContext
        ctx.insert(place)
        try? ctx.save()
        reload()
        Haptics.tap()
        return place
    }

    func toggleVisited(_ place: Place) {
        place.visited.toggle()
        try? container.mainContext.save()
        if place.visited { Haptics.success() } else { Haptics.soft() }
        reload()
    }

    func delete(_ place: Place) {
        container.mainContext.delete(place)
        try? container.mainContext.save()
        reload()
    }

    // MARK: Stats (all derived)

    /// Completion for the currently selected list.
    var currentStats: CompletionStats { CompletionStats.from(visiblePlaces) }

    /// Completion across every list (used by Stats / trophy card).
    var overallStats: CompletionStats { CompletionStats.from(places) }

    /// Visited / total per continent across ALL lists, in display order.
    func continentBreakdown() -> [(continent: Continent, visited: Int, total: Int)] {
        Continent.ordered.compactMap { continent in
            let inContinent = places.filter { $0.continentValue == continent }
            guard !inContinent.isEmpty else { return nil }
            let visited = inContinent.filter { $0.visited }.count
            return (continent, visited, inContinent.count)
        }
    }

    // MARK: Lists (Pro)

    private func loadLists() {
        guard let data = UserDefaults.standard.data(forKey: kLists),
              let decoded = try? JSONDecoder().decode([TravelList].self, from: data),
              !decoded.isEmpty else {
            lists = [TravelList.defaultList]
            return
        }
        // The default list is always first and always present.
        var result = [TravelList.defaultList]
        result.append(contentsOf: decoded.filter { $0.id != TravelList.defaultID })
        lists = result
    }

    private func persistLists() {
        // Persist only the non-default custom lists.
        let custom = lists.filter { $0.id != TravelList.defaultID }
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: kLists)
        }
    }

    /// Custom lists are a Pro bonus. Returns nil (no-op) for free users — defense in depth.
    @discardableResult
    func addList(name: String) -> TravelList? {
        guard store?.isPro == true else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = TravelList(id: "list-\(UUID().uuidString.prefix(8))",
                              name: trimmed.isEmpty ? "New List" : trimmed)
        lists.append(list)
        persistLists()
        Haptics.tap()
        return list
    }

    /// Delete a custom list and all of its places. The default list cannot be deleted.
    func deleteList(id: String) {
        guard id != TravelList.defaultID else { return }
        for place in places where place.listID == id {
            container.mainContext.delete(place)
        }
        try? container.mainContext.save()
        lists.removeAll { $0.id == id }
        if selectedListID == id { selectedListID = TravelList.defaultID }
        persistLists()
        reload()
    }

    // MARK: Suggestions (bundled dataset)

    /// Suggestions from the bundle that the user hasn't already added to the current list.
    func suggestions(limit: Int = 12) -> [LandmarkSuggestion] {
        let existing = Set(visiblePlaces.map { $0.name.lowercased() })
        return Catalog.loadSuggestions()
            .filter { !existing.contains($0.name.lowercased()) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Account deletion / data wipe

    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: Place.self)
        try? ctx.save()
        lists = [TravelList.defaultList]
        selectedListID = TravelList.defaultID
        UserDefaults.standard.removeObject(forKey: kLists)
        reload()
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["STAMP_SEED"] == "1" else { return }
        let ctx = container.mainContext
        if ((try? ctx.fetch(FetchDescriptor<Place>()))?.isEmpty ?? true) {
            let sample = Catalog.loadSuggestions().prefix(14)
            for (i, s) in sample.enumerated() {
                ctx.insert(Place(name: s.name, continent: s.continent, vibe: s.vibe,
                                 visited: i % 3 == 0, listID: TravelList.defaultID))
            }
            try? ctx.save()
        }
    }
    #endif
}
