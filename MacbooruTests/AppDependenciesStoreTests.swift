import XCTest
@testable import Macbooru

@MainActor
final class AppDependenciesStoreTests: XCTestCase {
    func testInitialCredentialsLoadedAndSanitized() {
        let persistence = InMemoryCredentialsStore(
            initial: DanbooruCredentials(username: " user ", apiKey: " key ")
        )
        let store = AppDependenciesStore(
            persistence: persistence,
            factory: { _ in AppDependencies.makePreview() }
        )

        XCTAssertEqual(store.credentials.username, "user")
        XCTAssertEqual(store.credentials.apiKey, "key")
        XCTAssertTrue(store.hasCredentials)
    }

    func testUpdateCredentialsPersistsAndSanitizes() throws {
        let persistence = InMemoryCredentialsStore()
        let store = AppDependenciesStore(
            persistence: persistence,
            factory: { _ in AppDependencies.makePreview() }
        )

        try store.updateCredentials(username: "  name  ", apiKey: " 123 ")

        XCTAssertEqual(store.credentials, DanbooruCredentials(username: "name", apiKey: "123"))
        XCTAssertEqual(persistence.load(), DanbooruCredentials(username: "name", apiKey: "123"))
        XCTAssertTrue(store.hasCredentials)
    }

    func testClearingCredentialsRemovesAll() throws {
        let persistence = InMemoryCredentialsStore(
            initial: DanbooruCredentials(username: "name", apiKey: "123")
        )
        let store = AppDependenciesStore(
            persistence: persistence,
            factory: { _ in AppDependencies.makePreview() }
        )

        try store.updateCredentials(username: nil, apiKey: nil)

        XCTAssertEqual(store.credentials, .empty)
        XCTAssertFalse(store.hasCredentials)
        XCTAssertEqual(persistence.load(), .empty)
    }

    func testRefreshProfileSuccess() async {
        let persistence = InMemoryCredentialsStore(
            initial: DanbooruCredentials(username: "name", apiKey: "key")
        )
        let profile = UserProfile(id: 42, name: "Tester", level: "Gold", email: nil, createdAt: nil)
        let store = AppDependenciesStore(
            persistence: persistence,
            factory: { _ in makeStubDependencies(fetchResult: .success(profile)) }
        )

        await store.refreshProfile()

        XCTAssertEqual(store.profile, profile)
        XCTAssertNil(store.authenticationError)
    }

    func testRefreshProfileFailure() async {
        let persistence = InMemoryCredentialsStore(
            initial: DanbooruCredentials(username: "name", apiKey: "key")
        )
        struct SampleError: Error {}
        let store = AppDependenciesStore(
            persistence: persistence,
            factory: { _ in makeStubDependencies(fetchResult: .failure(SampleError())) }
        )

        await store.refreshProfile()

        XCTAssertNil(store.profile)
        XCTAssertNotNil(store.authenticationError)
    }

    func testHandleAuthenticationFailureSetsState() {
        let persistence = InMemoryCredentialsStore()
        let store = AppDependenciesStore(
            persistence: persistence,
            factory: { _ in AppDependencies.makePreview() }
        )

        store.handleAuthenticationFailure(message: "Invalid")

        XCTAssertEqual(store.authenticationError, "Invalid")
        XCTAssertNil(store.profile)
    }
}

private func makeStubDependencies(fetchResult: Result<UserProfile, Error>) -> AppDependencies {
    let preview = AppDependencies.makePreview()
    return AppDependencies(
        searchPosts: preview.searchPosts,
        autocompleteTags: preview.autocompleteTags,
        favoritePost: preview.favoritePost,
        votePost: preview.votePost,
        comments: preview.comments,
        fetchCurrentUser: StubFetchCurrentUserUseCase(result: fetchResult)
    )
}

private struct StubFetchCurrentUserUseCase: FetchCurrentUserUseCase {
    let result: Result<UserProfile, Error>
    func execute() async throws -> UserProfile {
        switch result {
        case .success(let profile):
            return profile
        case .failure(let error):
            throw error
        }
    }
}
