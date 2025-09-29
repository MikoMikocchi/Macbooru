import Foundation

struct Post: Identifiable, Codable, Hashable {
    let id: Int
    let createdAt: Date?
    let rating: String?
    let tagString: String?
    let fileUrl: String?
    let previewFileUrl: String?
    let largeFileUrl: String?
    let width: Int?
    let height: Int?
    let score: Int?
    let favCount: Int?
    let source: String?

    // Удобные URL, автоматически дополняющие относительные пути хостом Danbooru
    var fileURL: URL? { URL.makeDanbooruURL(fileUrl) }
    var previewURL: URL? { URL.makeDanbooruURL(previewFileUrl) }
    var largeURL: URL? { URL.makeDanbooruURL(largeFileUrl) }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case rating
        case tagString = "tag_string"
        case fileUrl = "file_url"
        case previewFileUrl = "preview_file_url"
        case largeFileUrl = "large_file_url"
        case width, height
        case score
        case favCount = "fav_count"
        case source
    }
}
