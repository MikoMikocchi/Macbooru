import Foundation

protocol PostsRepository {
    func recent(page: Int, limit: Int) async throws -> [Post]
    func byTags(_ query: String, page: Int, limit: Int) async throws -> [Post]
    func favorite(postID: Int) async throws
    func unfavorite(postID: Int) async throws
    func vote(postID: Int, score: Int) async throws
    func comments(for postID: Int, limit: Int) async throws -> [Comment]
    func createComment(postID: Int, body: String) async throws -> Comment
}

extension PostsRepository {
    func comments(for postID: Int) async throws -> [Comment] {
        try await comments(for: postID, limit: 40)
    }
}

final class PostsRepositoryImpl: PostsRepository {
    private let client: DanbooruClient

    init(client: DanbooruClient) { self.client = client }

    func recent(page: Int, limit: Int) async throws -> [Post] {
        try await client.fetchPosts(tags: nil, page: page, limit: limit)
    }

    func byTags(_ query: String, page: Int, limit: Int) async throws -> [Post] {
        try await client.fetchPosts(tags: query, page: page, limit: limit)
    }

    func favorite(postID: Int) async throws {
        try await client.favorite(postID: postID)
    }

    func unfavorite(postID: Int) async throws {
        try await client.unfavorite(postID: postID)
    }

    func vote(postID: Int, score: Int) async throws {
        try await client.vote(postID: postID, score: score)
    }

    func comments(for postID: Int, limit: Int) async throws -> [Comment] {
        try await client.fetchComments(postID: postID, limit: limit)
    }

    func createComment(postID: Int, body: String) async throws -> Comment {
        try await client.createComment(postID: postID, body: body)
    }
}
