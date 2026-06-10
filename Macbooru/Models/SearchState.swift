import Combine
import Foundation
import SwiftUI

enum Rating: String, CaseIterable, Identifiable, Codable, Hashable {
    case any, g, s, q, e
    var id: String { rawValue }
    var display: String { L10n.RatingLabels.display(for: self) }
    var tag: String? {
        switch self {
        case .any: return nil
        case .g: return "rating:g"
        case .s: return "rating:s"
        case .q: return "rating:q"
        case .e: return "rating:e"
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case recent  
    case newest  // order:id_desc
    case oldest  // order:id_asc
    case rank  
    case score  // order:score
    case favs  // order:favcount
    case random  

    var id: String { rawValue }
    var label: String { L10n.Sort.label(for: self) }
    var orderTag: String? {
        switch self {
        case .recent: return nil
        case .newest: return "order:id_desc"
        case .oldest: return "order:id_asc"
        case .rank: return "order:rank"
        case .score: return "order:score"
        case .favs: return "order:favcount"
        case .random: return "order:random"
        }
    }
}

enum TileSize: String, CaseIterable, Identifiable, Hashable {
    case small, medium, large
    var id: String { rawValue }
    var title: String { L10n.TileSizeLabels.title(for: self) }
    var height: CGFloat {
        switch self {
        case .small: return 120
        case .medium: return 150
        case .large: return 190
        }
    }
    var minColumnWidth: CGFloat {
        switch self {
        case .small: return 130
        case .medium: return 160
        case .large: return 200
        }
    }
}

final class SearchState: ObservableObject {
    private let defaults: UserDefaults

    private enum Keys {
        static let blurSensitive = "settings.blurSensitiveDefault"
        static let lowPerformance = "settings.lowPerformance"
        static let infiniteScroll = "settings.infiniteScrollEnabled"
    }

    @Published var tags: String = ""
    @Published var rating: Rating = .any
    @Published var tileSize: TileSize = .medium
    @Published var sort: SortMode = .recent
    @Published var page: Int = 1
    @Published var pageSize: Int = 30
    @Published var searchTrigger: Int = 0
    @Published var blurSensitive: Bool
    @Published var lowPerformance: Bool = false {
        didSet { defaults.set(lowPerformance, forKey: Keys.lowPerformance) }
    }
    // Infinite scroll option: when enabled, auto-loads next pages while scrolling
    @Published var infiniteScrollEnabled: Bool = false {
        didSet { defaults.set(infiniteScrollEnabled, forKey: Keys.infiniteScroll) }
    }
    // Pool search (optional). If set to a valid number, adds `pool:ID` to query
    @Published var poolID: String = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let persistedDefault = defaults.object(forKey: Keys.blurSensitive) as? Bool {
            blurSensitive = persistedDefault
        } else {
            blurSensitive = true
        }
        if defaults.object(forKey: Keys.lowPerformance) != nil {
            lowPerformance = defaults.bool(forKey: Keys.lowPerformance)
        }
        if defaults.object(forKey: Keys.infiniteScroll) != nil {
            infiniteScrollEnabled = defaults.bool(forKey: Keys.infiniteScroll)
        }
    }

    
    var danbooruQuery: String? {
        let poolTag: String? = {
            let trimmed = poolID.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id = Int(trimmed), id > 0 { return "pool:\(id)" }
            return nil
        }()
        let parts: [String] = [
            rating.tag,
            sort.orderTag,
            poolTag,
            tags.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .compactMap { s in
            guard let s = s, !s.isEmpty else { return nil }
            return s
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    func resetForNewSearch() {
        page = 1
        searchTrigger &+= 1
    }
}
