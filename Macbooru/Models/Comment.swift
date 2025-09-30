import Foundation

struct Comment: Identifiable, Codable, Hashable {
    let id: Int
    let postID: Int
    let creatorID: Int?
    let creatorName: String?
    let body: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case creatorID = "creator_id"
        case creatorName = "creator_name"
        case body
        case createdAt = "created_at"
    }
}
