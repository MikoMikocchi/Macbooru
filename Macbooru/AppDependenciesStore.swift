import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDependenciesStore: ObservableObject {
    @Published private(set) var dependencies: AppDependencies
    @Published private(set) var credentials: DanbooruCredentials

    private let persistence: CredentialsPersisting

    init(persistence: CredentialsPersisting = KeychainCredentialsStore()) {
        self.persistence = persistence
        let stored = persistence.load().sanitized
        self.credentials = stored
        self.dependencies = AppDependencies.makeDefault(config: stored.asConfig())
    }

    func updateCredentials(username: String?, apiKey: String?) throws {
        let creds = DanbooruCredentials(username: username, apiKey: apiKey).sanitized
        if !creds.hasCredentials {
            try persistence.clear()
            credentials = .empty
            dependencies = AppDependencies.makeDefault(config: DanbooruCredentials.empty.asConfig())
            return
        }
        try persistence.save(creds)
        credentials = creds
        dependencies = AppDependencies.makeDefault(config: creds.asConfig())
    }

    func clearCredentials() throws {
        try persistence.clear()
        credentials = .empty
        dependencies = AppDependencies.makeDefault(config: DanbooruCredentials.empty.asConfig())
    }

    var hasCredentials: Bool { credentials.hasCredentials }
}
