import Foundation
import SwiftData

/// A continent tag. Raw values are stable strings persisted on each `Place`.
enum Continent: String, CaseIterable, Identifiable, Codable {
    case africa, asia, europe, northAmerica, southAmerica, oceania, antarctica

    var id: String { rawValue }

    var label: String {
        switch self {
        case .africa: return "Africa"
        case .asia: return "Asia"
        case .europe: return "Europe"
        case .northAmerica: return "North America"
        case .southAmerica: return "South America"
        case .oceania: return "Oceania"
        case .antarctica: return "Antarctica"
        }
    }

    /// Stable display order used by Stats.
    static var ordered: [Continent] {
        [.africa, .asia, .europe, .northAmerica, .southAmerica, .oceania, .antarctica]
    }
}

/// A "vibe" tag describing the kind of trip. `.none` means untagged.
enum Vibe: String, CaseIterable, Identifiable, Codable {
    case none, city, nature, beach, history, food, adventure

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return ""
        case .city: return "City"
        case .nature: return "Nature"
        case .beach: return "Beach"
        case .history: return "History"
        case .food: return "Food"
        case .adventure: return "Adventure"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "tag"
        case .city: return "building.2"
        case .nature: return "leaf"
        case .beach: return "beach.umbrella"
        case .history: return "building.columns"
        case .food: return "fork.knife"
        case .adventure: return "figure.hiking"
        }
    }

    /// The user-selectable vibes (excludes `.none`).
    static var selectable: [Vibe] { [.city, .nature, .beach, .history, .food, .adventure] }
}

/// A place on a bucket list. All properties have defaults and there are no unique constraints,
/// so the schema is CloudKit-mirroring compatible.
@Model
final class Place {
    var id: UUID = UUID()
    var name: String = ""
    var continentRaw: String = Continent.europe.rawValue
    var vibeRaw: String = Vibe.none.rawValue
    var visited: Bool = false
    /// Which list this place belongs to. Empty string == the default (free) list.
    var listID: String = ""
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), name: String = "", continent: Continent = .europe,
         vibe: Vibe = .none, visited: Bool = false, listID: String = "",
         createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.continentRaw = continent.rawValue
        self.vibeRaw = vibe.rawValue
        self.visited = visited
        self.listID = listID
        self.createdAt = createdAt
    }

    var continentValue: Continent {
        get { Continent(rawValue: continentRaw) ?? .europe }
        set { continentRaw = newValue.rawValue }
    }

    var vibeValue: Vibe {
        get { Vibe(rawValue: vibeRaw) ?? .none }
        set { vibeRaw = newValue.rawValue }
    }
}
