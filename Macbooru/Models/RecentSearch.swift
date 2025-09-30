import Foundation

struct RecentSearch: Codable, Identifiable, Hashable {
    var id: UUID
    var query: String
    var rating: Rating
    var sort: SortMode?
    var createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(), query: String, rating: Rating, sort: SortMode? = nil,
        createdAt: Date = .now, lastUsedAt: Date = .now
    ) {
        self.id = id
        self.query = query
        self.rating = rating
        self.sort = sort
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

final class RecentSearchStore {
    private let key = "macbooru.recentSearches"
    private let defaults: UserDefaults
    private let maxCount = 30

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func list() -> [RecentSearch] {
        guard let data = defaults.data(forKey: key) else { return [] }
        if let arr = try? JSONDecoder().decode([RecentSearch].self, from: data) {
            return sort(arr)
        }
        return []
    }

    func addOrTouch(query: String, rating: Rating, sort: SortMode?) {
        var items = list()
        if let idx = items.firstIndex(where: {
            $0.query == query && $0.rating == rating && $0.sort == sort
        }) {
            items[idx].lastUsedAt = .now
        } else {
            items.append(RecentSearch(query: query, rating: rating, sort: sort))
        }
        save(items)
    }

    func remove(id: UUID) {
        var items = list()
        items.removeAll { $0.id == id }
        save(items)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    private func sort(_ items: [RecentSearch]) -> [RecentSearch] {
        items.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    private func save(_ items: [RecentSearch]) {
        let sorted = sort(items)
        let capped = Array(sorted.prefix(maxCount))
        if let data = try? JSONEncoder().encode(capped) {
            defaults.set(data, forKey: key)
        }
    }
}
