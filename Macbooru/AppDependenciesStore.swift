import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDependenciesStore: ObservableObject {
    @Published private(set) var dependencies: AppDependencies
    @Published private(set) var credentials: DanbooruCredentials
    @Published private(set) var profile: UserProfile? = nil
    @Published private(set) var authenticationError: String? = nil

    private let persistence: CredentialsPersisting
    private let factory: @MainActor (DanbooruConfig) -> AppDependencies

    init(
        persistence: CredentialsPersisting,
        factory: @MainActor @escaping (DanbooruConfig) -> AppDependencies = AppDependencies
            .makeDefault
    ) {
        self.persistence = persistence
        self.factory = factory
        let stored = persistence.load().sanitized
        self.credentials = stored
        self.dependencies = factory(stored.asConfig())
        if stored.hasCredentials {
            Task { await refreshProfile() }
        }
    }

    convenience init() {
        self.init(persistence: KeychainCredentialsStore())
    }

    func updateCredentials(username: String?, apiKey: String?) throws {
        let creds = DanbooruCredentials(username: username, apiKey: apiKey).sanitized
        if !creds.hasCredentials {
            try persistence.clear()
            credentials = .empty
            dependencies = factory(DanbooruCredentials.empty.asConfig())
            profile = nil
            authenticationError = nil
            return
        }
        try persistence.save(creds)
        credentials = creds
        dependencies = factory(creds.asConfig())
        Task { await refreshProfile() }
    }

    func clearCredentials() throws {
        try persistence.clear()
        credentials = .empty
        dependencies = factory(DanbooruCredentials.empty.asConfig())
        profile = nil
        authenticationError = nil
    }

    func rebuildDependencies() {
        dependencies = factory(credentials.asConfig())
        if credentials.hasCredentials {
            Task { await refreshProfile() }
        }
    }

    var hasCredentials: Bool { credentials.hasCredentials }

    func refreshProfile() async {
        guard credentials.hasCredentials else { return }
        do {
            let user = try await dependencies.fetchCurrentUser.execute()
            profile = user
            authenticationError = nil
        } catch {
            handleAuthenticationFailure(message: friendlyMessage(for: error))
        }
    }

    func handleAuthenticationFailure(message: String) {
        authenticationError = message
        profile = nil
    }

    private func friendlyMessage(for error: Error) -> String {
        NetworkErrorMessage.friendly(for: error)
    }
}
