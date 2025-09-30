import SwiftUI

struct AppDependencies {
    let searchPosts: SearchPostsUseCase
    let autocompleteTags: AutocompleteTagsUseCase
    let favoritePost: FavoritePostUseCase
    let votePost: VotePostUseCase
    let comments: CommentsUseCase

    static func makeDefault(config: DanbooruConfig = DanbooruConfig()) -> AppDependencies {
        let client = DanbooruClient(config: config)
        let postsRepository = PostsRepositoryImpl(client: client)
        let tagsRepository = TagsRepositoryImpl(client: client)

        return AppDependencies(
            searchPosts: DefaultSearchPostsUseCase(postsRepository: postsRepository),
            autocompleteTags: DefaultAutocompleteTagsUseCase(tagsRepository: tagsRepository),
            favoritePost: DefaultFavoritePostUseCase(postsRepository: postsRepository),
            votePost: DefaultVotePostUseCase(postsRepository: postsRepository),
            comments: DefaultCommentsUseCase(postsRepository: postsRepository)
        )
    }

    static func makePreview() -> AppDependencies {
        AppDependencies(
            searchPosts: PreviewSearchPostsUseCase(),
            autocompleteTags: PreviewAutocompleteTagsUseCase(),
            favoritePost: PreviewFavoritePostUseCase(),
            votePost: PreviewVotePostUseCase(),
            comments: PreviewCommentsUseCase()
        )
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies = .makePreview()
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - Preview Use Cases

private struct PreviewSearchPostsUseCase: SearchPostsUseCase {
    func execute(query: String?, page: Int, limit: Int) async throws -> [Post] {
        []
    }
}

private struct PreviewAutocompleteTagsUseCase: AutocompleteTagsUseCase {
    func execute(prefix: String, limit: Int) async throws -> [Tag] {
        []
    }
}

private struct PreviewFavoritePostUseCase: FavoritePostUseCase {
    func favorite(postID: Int) async throws {}
    func unfavorite(postID: Int) async throws {}
}

private struct PreviewVotePostUseCase: VotePostUseCase {
    func vote(postID: Int, score: Int) async throws {}
}

private struct PreviewCommentsUseCase: CommentsUseCase {
    func load(postID: Int, limit: Int) async throws -> [Comment] { [] }
    func create(postID: Int, body: String) async throws -> Comment {
        Comment(id: .random(in: 1...9999), postID: postID, creatorID: nil, creatorName: "Preview", body: body, createdAt: .now)
    }
}
