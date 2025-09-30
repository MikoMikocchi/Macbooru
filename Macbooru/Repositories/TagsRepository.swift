import Foundation

protocol TagsRepository {
    func autocomplete(prefix: String, limit: Int) async throws -> [Tag]
}

final class TagsRepositoryImpl: TagsRepository {
    private let client: DanbooruClient
    init(client: DanbooruClient) { self.client = client }

    func autocomplete(prefix: String, limit: Int = 10) async throws -> [Tag] {
        try await client.fetchTags(prefix: prefix, limit: limit)
    }
}
