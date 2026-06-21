import Foundation

/// One suggested landmark from the bundled `landmarks.json` dataset (factual place names).
struct LandmarkSuggestion: Identifiable, Equatable, Codable {
    var name: String
    var continent: Continent
    var vibe: Vibe

    var id: String { name }

    private enum CodingKeys: String, CodingKey { case name, continent, vibe }

    init(name: String, continent: Continent, vibe: Vibe) {
        self.name = name
        self.continent = continent
        self.vibe = vibe
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        let cont = try c.decode(String.self, forKey: .continent)
        let vb = try c.decodeIfPresent(String.self, forKey: .vibe) ?? Vibe.none.rawValue
        continent = Continent(rawValue: cont) ?? .europe
        vibe = Vibe(rawValue: vb) ?? .none
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(continent.rawValue, forKey: .continent)
        try c.encode(vibe.rawValue, forKey: .vibe)
    }
}

/// Loads the bundled suggestion dataset once, at launch.
enum Catalog {
    /// Decode `landmarks.json` from the given bundle. Returns [] if missing/corrupt (never throws).
    static func loadSuggestions(from bundle: Bundle = .main) -> [LandmarkSuggestion] {
        guard let url = bundle.url(forResource: "landmarks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LandmarkSuggestion].self, from: data)
        else { return [] }
        return decoded
    }

    /// Parse suggestions from raw JSON data (used by tests). Returns [] on failure.
    static func parse(_ data: Data) -> [LandmarkSuggestion] {
        (try? JSONDecoder().decode([LandmarkSuggestion].self, from: data)) ?? []
    }
}
