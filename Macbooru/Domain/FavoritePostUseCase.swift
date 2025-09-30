import Foundation

protocol FavoritePostUseCase {
    func favorite(postID: Int) async throws
    func unfavorite(postID: Int) async throws
}

struct DefaultFavoritePostUseCase: FavoritePostUseCase {
    private let postsRepository: PostsRepository

    init(postsRepository: PostsRepository) {
        self.postsRepository = postsRepository
    }

    func favorite(postID: Int) async throws {
        try await postsRepository.favorite(postID: postID)
    }

    func unfavorite(postID: Int) async throws {
        try await postsRepository.unfavorite(postID: postID)
    }
}
