import Combine
import Foundation
import SwiftUI

enum Rating: String, CaseIterable, Identifiable, Codable, Hashable {
    case any, g, s, q, e
    var id: String { rawValue }
    var display: String {
        switch self {
        case .any: return "Any"
        case .g: return "G"
        case .s: return "S"
        case .q: return "Q"
        case .e: return "E"
        }
    }
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
    case recent  // по умолчанию (без order)
    case newest  // order:id_desc
    case oldest  // order:id_asc
    case rank  // order:rank (популярное/трендовое)
    case score  // order:score
    case favs  // order:favcount
    case random  // order:random (может игнорировать другие фильтры)

    var id: String { rawValue }
    var label: String {
        switch self {
        case .recent: return "Recent"
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .rank: return "Rank"
        case .score: return "Score"
        case .favs: return "Favs"
        case .random: return "Random"
        }
    }
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
    var title: String { rawValue.capitalized }
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
    @Published var tags: String = ""
    @Published var rating: Rating = .any
    @Published var tileSize: TileSize = .medium
    @Published var sort: SortMode = .recent
    @Published var page: Int = 1
    @Published var searchTrigger: Int = 0
    @Published var blurSensitive: Bool = true

    // составной запрос для Danbooru: rating:*, затем пользовательские теги
    var danbooruQuery: String? {
        let parts: [String] = [
            rating.tag, sort.orderTag, tags.trimmingCharacters(in: .whitespacesAndNewlines),
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
