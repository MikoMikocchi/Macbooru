import XCTest
@testable import Macbooru

final class SearchPostsUseCaseTests: XCTestCase {
    func testExecuteWithoutQueryUsesRecent() async throws {
        let repo = MockPostsRepository()
        repo.recentResult = [.fixture(id: 1)]
        let useCase = DefaultSearchPostsUseCase(postsRepository: repo)

        let posts = try await useCase.execute(query: nil, page: 2, limit: 40)

        XCTAssertEqual(posts.map(\.id), [1])
        XCTAssertEqual(repo.lastRecentParameters?.page, 2)
        XCTAssertEqual(repo.lastRecentParameters?.limit, 40)
        XCTAssertNil(repo.lastByTagsParameters)
    }

    func testExecuteWithWhitespaceFallsBackToRecent() async throws {
        let repo = MockPostsRepository()
        repo.recentResult = [.fixture(id: 5)]
        let useCase = DefaultSearchPostsUseCase(postsRepository: repo)

        let posts = try await useCase.execute(query: "   ", page: 1, limit: 30)

        XCTAssertEqual(posts.map(\.id), [5])
        XCTAssertNotNil(repo.lastRecentParameters)
        XCTAssertNil(repo.lastByTagsParameters)
    }

    func testExecuteWithTagsUsesByTags() async throws {
        let repo = MockPostsRepository()
        repo.byTagsResult = [.fixture(id: 10)]
        let useCase = DefaultSearchPostsUseCase(postsRepository: repo)

        let posts = try await useCase.execute(query: " rating:s tag1 ", page: 3, limit: 15)

        XCTAssertEqual(posts.map(\.id), [10])
        XCTAssertEqual(repo.lastByTagsParameters?.query, "rating:s tag1")
        XCTAssertEqual(repo.lastByTagsParameters?.page, 3)
        XCTAssertEqual(repo.lastByTagsParameters?.limit, 15)
    }
}

private final class MockPostsRepository: PostsRepository {
    var recentResult: [Post] = []
    var byTagsResult: [Post] = []

    private(set) var lastRecentParameters: (page: Int, limit: Int)?
    private(set) var lastByTagsParameters: (query: String, page: Int, limit: Int)?

    func recent(page: Int, limit: Int) async throws -> [Post] {
        lastRecentParameters = (page, limit)
        return recentResult
    }

    func byTags(_ query: String, page: Int, limit: Int) async throws -> [Post] {
        lastByTagsParameters = (query, page, limit)
        return byTagsResult
    }

    func favorite(postID: Int) async throws {}

    func unfavorite(postID: Int) async throws {}

    func vote(postID: Int, score: Int) async throws {}

    func comments(for postID: Int, limit: Int) async throws -> [Comment] { [] }

    func createComment(postID: Int, body: String) async throws -> Comment {
        Comment(id: 1, postID: postID, creatorID: nil, creatorName: nil, body: body, createdAt: nil)
    }
}

private extension Post {
    static func fixture(id: Int) -> Post {
        Post(
            id: id,
            createdAt: nil,
            rating: nil,
            tagString: nil,
            tagStringArtist: nil,
            tagStringCopyright: nil,
            tagStringCharacter: nil,
            tagStringGeneral: nil,
            tagStringMeta: nil,
            fileUrl: nil,
            previewFileUrl: nil,
            largeFileUrl: nil,
            width: nil,
            height: nil,
            score: nil,
            favCount: nil,
            source: nil
        )
    }
}
