import Foundation

protocol FetchCurrentUserUseCase {
    func execute() async throws -> UserProfile
}

struct DefaultFetchCurrentUserUseCase: FetchCurrentUserUseCase {
    private let repository: AccountRepository

    init(repository: AccountRepository) {
        self.repository = repository
    }

    func execute() async throws -> UserProfile {
        try await repository.currentUser()
    }
}
