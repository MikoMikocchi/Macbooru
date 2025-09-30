import Foundation

struct Post: Identifiable, Codable, Hashable {
    let id: Int
    let createdAt: Date?
    let rating: String?
    let tagString: String?
    // Отдельные группы тегов от Danbooru (если приходят в ответе)
    let tagStringArtist: String?
    let tagStringCopyright: String?
    let tagStringCharacter: String?
    let tagStringGeneral: String?
    let tagStringMeta: String?
    let fileUrl: String?
    let previewFileUrl: String?
    let largeFileUrl: String?
    let width: Int?
    let height: Int?
    let score: Int?
    let favCount: Int?
    let source: String?
    let isFavorited: Bool?
    let upScore: Int?
    let downScore: Int?

    // Удобные URL, автоматически дополняющие относительные пути хостом Danbooru
    var fileURL: URL? { URL.makeDanbooruURL(fileUrl) }
    var previewURL: URL? { URL.makeDanbooruURL(previewFileUrl) }
    var largeURL: URL? { URL.makeDanbooruURL(largeFileUrl) }

    // Удобные разбиения по группам
    var tagsArtist: [String] { Post.split(tagStringArtist) }
    var tagsCopyright: [String] { Post.split(tagStringCopyright) }
    var tagsCharacter: [String] { Post.split(tagStringCharacter) }
    var tagsGeneral: [String] { Post.split(tagStringGeneral) }
    var tagsMeta: [String] { Post.split(tagStringMeta) }
    var allTags: [String] { Post.split(tagString) }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case rating
        case tagString = "tag_string"
        case tagStringArtist = "tag_string_artist"
        case tagStringCopyright = "tag_string_copyright"
        case tagStringCharacter = "tag_string_character"
        case tagStringGeneral = "tag_string_general"
        case tagStringMeta = "tag_string_meta"
        case fileUrl = "file_url"
        case previewFileUrl = "preview_file_url"
        case largeFileUrl = "large_file_url"
        case width, height
        case score
        case favCount = "fav_count"
        case source
        case isFavorited = "is_favorited"
        case upScore = "up_score"
        case downScore = "down_score"
    }

    private static func split(_ s: String?) -> [String] {
        guard let s, !s.isEmpty else { return [] }
        return s.split(separator: " ").map(String.init)
    }
}
