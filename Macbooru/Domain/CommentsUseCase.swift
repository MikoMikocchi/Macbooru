import Foundation

protocol CommentsUseCase {
    func load(postID: Int, limit: Int) async throws -> [Comment]
    func create(postID: Int, body: String) async throws -> Comment
}

struct DefaultCommentsUseCase: CommentsUseCase {
    private let postsRepository: PostsRepository

    init(postsRepository: PostsRepository) {
        self.postsRepository = postsRepository
    }

    func load(postID: Int, limit: Int) async throws -> [Comment] {
        try await postsRepository.comments(for: postID, limit: limit)
    }

    func create(postID: Int, body: String) async throws -> Comment {
        try await postsRepository.createComment(postID: postID, body: body)
    }
}
