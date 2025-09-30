import Foundation

protocol SearchPostsUseCase {
    func execute(query: String?, page: Int, limit: Int) async throws -> [Post]
}

struct DefaultSearchPostsUseCase: SearchPostsUseCase {
    private let postsRepository: PostsRepository

    init(postsRepository: PostsRepository) {
        self.postsRepository = postsRepository
    }

    func execute(query: String?, page: Int, limit: Int) async throws -> [Post] {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return try await postsRepository.byTags(trimmed, page: page, limit: limit)
        } else {
            return try await postsRepository.recent(page: page, limit: limit)
        }
    }
}
