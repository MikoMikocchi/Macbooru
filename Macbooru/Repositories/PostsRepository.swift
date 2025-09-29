import Foundation

protocol PostsRepository {
    func recent(page: Int, limit: Int) async throws -> [Post]
    func byTags(_ query: String, page: Int, limit: Int) async throws -> [Post]
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
}
