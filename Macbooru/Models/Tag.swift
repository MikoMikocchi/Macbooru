import Foundation

struct Tag: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let category: Int?
    let postCount: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case category
        case postCount = "post_count"
    }

    var displayName: String { name.replacingOccurrences(of: "_", with: " ") }
    var kind: String {
        switch category ?? -1 {
        case 0: return "general"
        case 1: return "artist"
        case 3: return "copyright"
        case 4: return "character"
        case 5: return "meta"
        default: return "tag"
        }
    }
}
