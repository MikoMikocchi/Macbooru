import Foundation

struct SavedSearch: Codable, Identifiable, Hashable {
    var id: UUID
    var query: String  // строка тегов (без rating)
    var rating: Rating  // выбранный рейтинг
    var sort: SortMode?  // опционально: сохранённая сортировка
    var pinned: Bool  // закреплён
    var createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(), query: String, rating: Rating, sort: SortMode? = nil,
        pinned: Bool = false,
        createdAt: Date = .now, lastUsedAt: Date = .now
    ) {
        self.id = id
        self.query = query
        self.rating = rating
        self.sort = sort
        self.pinned = pinned
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

final class SavedSearchStore {
    private let key = "macbooru.savedSearches"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func list() -> [SavedSearch] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            let arr = try JSONDecoder().decode([SavedSearch].self, from: data)
            return sort(arr)
        } catch {
            return []
        }
    }

    func addOrUpdate(query: String, rating: Rating, sort: SortMode? = nil) {
        var items = list()
        if let idx = items.firstIndex(where: { $0.query == query && $0.rating == rating }) {
            items[idx].lastUsedAt = .now
            if let sort { items[idx].sort = sort }
        } else {
            items.append(SavedSearch(query: query, rating: rating, sort: sort))
        }
        save(items)
    }

    func togglePin(id: UUID) {
        var items = list()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        save(items)
    }

    func remove(id: UUID) {
        var items = list()
        items.removeAll { $0.id == id }
        save(items)
    }

    func touch(id: UUID) {
        var items = list()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].lastUsedAt = .now
        save(items)
    }

    private func sort(_ items: [SavedSearch]) -> [SavedSearch] {
        items.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned && !b.pinned }
            return a.lastUsedAt > b.lastUsedAt
        }
    }

    private func save(_ items: [SavedSearch]) {
        // Сортируем и ограничиваем: pinned вне лимита, неприкреплённые — до 20
        let sorted = sort(items)
        let pinned = sorted.filter { $0.pinned }
        let others = sorted.filter { !$0.pinned }
        let capped = pinned + others.prefix(20)
        if let data = try? JSONEncoder().encode(capped) {
            defaults.set(data, forKey: key)
        }
    }
}
