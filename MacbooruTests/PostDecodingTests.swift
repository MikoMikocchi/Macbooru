import XCTest
@testable import Macbooru

final class PostDecodingTests: XCTestCase {
    func testDecodePost() throws {
        let json = """
        [{
          "id": 123,
          "created_at": "2024-04-01T12:34:56.000-04:00",
          "rating": "s",
          "tag_string": "tag1 tag2",
          "file_url": "https://example.com/file.jpg",
          "preview_file_url": "https://example.com/preview.jpg",
          "large_file_url": "https://example.com/large.jpg",
          "width": 1024,
          "height": 768,
          "score": 42,
          "fav_count": 3,
          "source": "https://artist.example/post/1",
          "is_favorited": true,
          "up_score": 123,
          "down_score": 5
        }]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let posts = try decoder.decode([Post].self, from: json)
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts.first?.id, 123)
        XCTAssertEqual(posts.first?.rating, "s")
        XCTAssertEqual(posts.first?.score, 42)
        XCTAssertEqual(posts.first?.isFavorited, true)
        XCTAssertEqual(posts.first?.upScore, 123)
        XCTAssertEqual(posts.first?.downScore, 5)
    }
}
