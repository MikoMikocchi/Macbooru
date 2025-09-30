import XCTest
@testable import Macbooru

@MainActor
final class AppDependenciesStoreTests: XCTestCase {
    func testInitialCredentialsLoadedAndSanitized() {
        let persistence = InMemoryCredentialsStore(
            initial: DanbooruCredentials(username: " user ", apiKey: " key ")
        )
        let store = AppDependenciesStore(persistence: persistence)

        XCTAssertEqual(store.credentials.username, "user")
        XCTAssertEqual(store.credentials.apiKey, "key")
        XCTAssertTrue(store.hasCredentials)
    }

    func testUpdateCredentialsPersistsAndSanitizes() throws {
        let persistence = InMemoryCredentialsStore()
        let store = AppDependenciesStore(persistence: persistence)

        try store.updateCredentials(username: "  name  ", apiKey: " 123 ")

        XCTAssertEqual(store.credentials, DanbooruCredentials(username: "name", apiKey: "123"))
        XCTAssertEqual(persistence.load(), DanbooruCredentials(username: "name", apiKey: "123"))
        XCTAssertTrue(store.hasCredentials)
    }

    func testClearingCredentialsRemovesAll() throws {
        let persistence = InMemoryCredentialsStore(
            initial: DanbooruCredentials(username: "name", apiKey: "123")
        )
        let store = AppDependenciesStore(persistence: persistence)

        try store.updateCredentials(username: nil, apiKey: nil)

        XCTAssertEqual(store.credentials, .empty)
        XCTAssertFalse(store.hasCredentials)
        XCTAssertEqual(persistence.load(), .empty)
    }
}
