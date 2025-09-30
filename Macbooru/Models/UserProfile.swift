import Foundation

struct UserProfile: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let level: String?
    let email: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case level = "level_string"
        case email = "email"
        case createdAt = "created_at"
    }
}
