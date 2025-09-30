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

final class FavoritePostUseCaseTests: XCTestCase {
    func testFavoriteInvokesRepository() async throws {
        let repo = MockPostsRepository()
        let useCase = DefaultFavoritePostUseCase(postsRepository: repo)

        try await useCase.favorite(postID: 42)

        XCTAssertEqual(repo.favoriteCalls, [42])
    }

    func testUnfavoriteInvokesRepository() async throws {
        let repo = MockPostsRepository()
        let useCase = DefaultFavoritePostUseCase(postsRepository: repo)

        try await useCase.unfavorite(postID: 55)

        XCTAssertEqual(repo.unfavoriteCalls, [55])
    }
}

final class VotePostUseCaseTests: XCTestCase {
    func testVoteInvokesRepository() async throws {
        let repo = MockPostsRepository()
        let useCase = DefaultVotePostUseCase(postsRepository: repo)

        try await useCase.vote(postID: 77, score: 3)

        XCTAssertEqual(repo.voteCalls.count, 1)
        XCTAssertEqual(repo.voteCalls.first?.postID, 77)
        XCTAssertEqual(repo.voteCalls.first?.score, 3)
    }
}

final class CommentsUseCaseTests: XCTestCase {
    func testLoadReturnsRepositoryData() async throws {
        let repo = MockPostsRepository()
        repo.commentsResult = [.fixture(id: 1, body: "Hi"), .fixture(id: 2, body: "Hello")]
        let useCase = DefaultCommentsUseCase(postsRepository: repo)

        let comments = try await useCase.load(postID: 90, limit: 10)

        XCTAssertEqual(repo.lastCommentsParameters?.postID, 90)
        XCTAssertEqual(repo.lastCommentsParameters?.page, 1)
        XCTAssertEqual(repo.lastCommentsParameters?.limit, 10)
        XCTAssertEqual(comments.map(\.id), [1, 2])
    }

    func testCreateReturnsCreatedComment() async throws {
        let repo = MockPostsRepository()
        repo.createCommentResult = .fixture(id: 5, body: "New")
        let useCase = DefaultCommentsUseCase(postsRepository: repo)

        let comment = try await useCase.create(postID: 11, body: "Hello")

        XCTAssertEqual(repo.lastCreateParameters?.postID, 11)
        XCTAssertEqual(repo.lastCreateParameters?.body, "Hello")
        XCTAssertEqual(comment.id, 5)
    }

    func testLoadWithSecondPage() async throws {
        let repo = MockPostsRepository()
        repo.commentsResult = [.fixture(id: 3, body: "Later")]
        let useCase = DefaultCommentsUseCase(postsRepository: repo)

        _ = try await useCase.load(postID: 12, page: 2, limit: 20)

        XCTAssertEqual(repo.lastCommentsParameters?.page, 2)
        XCTAssertEqual(repo.lastCommentsParameters?.limit, 20)
    }
}

private final class MockPostsRepository: PostsRepository {
    var recentResult: [Post] = []
    var byTagsResult: [Post] = []
    var commentsResult: [Comment] = []
    var createCommentResult: Comment = .fixture(id: 1, body: "")

    private(set) var lastRecentParameters: (page: Int, limit: Int)?
    private(set) var lastByTagsParameters: (query: String, page: Int, limit: Int)?
    private(set) var lastCommentsParameters: (postID: Int, page: Int, limit: Int)?
    private(set) var lastCreateParameters: (postID: Int, body: String)?
    private(set) var favoriteCalls: [Int] = []
    private(set) var unfavoriteCalls: [Int] = []
    private(set) var voteCalls: [(postID: Int, score: Int)] = []

    func recent(page: Int, limit: Int) async throws -> [Post] {
        lastRecentParameters = (page, limit)
        return recentResult
    }

    func byTags(_ query: String, page: Int, limit: Int) async throws -> [Post] {
        lastByTagsParameters = (query, page, limit)
        return byTagsResult
    }

    func favorite(postID: Int) async throws {
        favoriteCalls.append(postID)
    }

    func unfavorite(postID: Int) async throws {
        unfavoriteCalls.append(postID)
    }

    func vote(postID: Int, score: Int) async throws {
        voteCalls.append((postID, score))
    }

    func comments(for postID: Int, page: Int, limit: Int) async throws -> [Comment] {
        lastCommentsParameters = (postID, page, limit)
        return commentsResult
    }

    func createComment(postID: Int, body: String) async throws -> Comment {
        lastCreateParameters = (postID, body)
        return createCommentResult
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
            source: nil,
            isFavorited: nil,
            upScore: nil,
            downScore: nil
        )
    }
}

private extension Comment {
    static func fixture(id: Int, postID: Int = 1, body: String) -> Comment {
        Comment(
            id: id,
            postID: postID,
            creatorID: nil,
            creatorName: "Tester",
            body: body,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id))
        )
    }
}
