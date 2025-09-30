import Foundation

protocol VotePostUseCase {
    func vote(postID: Int, score: Int) async throws
}

struct DefaultVotePostUseCase: VotePostUseCase {
    private let postsRepository: PostsRepository

    init(postsRepository: PostsRepository) {
        self.postsRepository = postsRepository
    }

    func vote(postID: Int, score: Int) async throws {
        try await postsRepository.vote(postID: postID, score: score)
    }
}
