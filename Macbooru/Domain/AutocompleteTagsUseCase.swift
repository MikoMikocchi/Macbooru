import Foundation

protocol AutocompleteTagsUseCase {
    func execute(prefix: String, limit: Int) async throws -> [Tag]
}

struct DefaultAutocompleteTagsUseCase: AutocompleteTagsUseCase {
    private let tagsRepository: TagsRepository

    init(tagsRepository: TagsRepository) {
        self.tagsRepository = tagsRepository
    }

    func execute(prefix: String, limit: Int) async throws -> [Tag] {
        try await tagsRepository.autocomplete(prefix: prefix, limit: limit)
    }
}
