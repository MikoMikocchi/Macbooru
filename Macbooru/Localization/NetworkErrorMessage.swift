import Foundation

enum NetworkErrorMessage {
    static func friendly(for error: Error) -> String {
        L10n.Error.message(for: error)
    }
}
