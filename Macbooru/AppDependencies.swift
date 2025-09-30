import SwiftUI

struct AppDependencies {
    let searchPosts: SearchPostsUseCase
    let autocompleteTags: AutocompleteTagsUseCase

    static func makeDefault(config: DanbooruConfig = DanbooruConfig()) -> AppDependencies {
        let client = DanbooruClient(config: config)
        let postsRepository = PostsRepositoryImpl(client: client)
        let tagsRepository = TagsRepositoryImpl(client: client)

        return AppDependencies(
            searchPosts: DefaultSearchPostsUseCase(postsRepository: postsRepository),
            autocompleteTags: DefaultAutocompleteTagsUseCase(tagsRepository: tagsRepository)
        )
    }

    static func makePreview() -> AppDependencies {
        AppDependencies(
            searchPosts: PreviewSearchPostsUseCase(),
            autocompleteTags: PreviewAutocompleteTagsUseCase()
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
