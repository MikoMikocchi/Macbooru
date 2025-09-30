import Foundation

protocol AccountRepository {
    func currentUser() async throws -> UserProfile
}

final class AccountRepositoryImpl: AccountRepository {
    private let client: DanbooruClient

    init(client: DanbooruClient) {
        self.client = client
    }

    func currentUser() async throws -> UserProfile {
        try await client.fetchCurrentUser()
    }
}
