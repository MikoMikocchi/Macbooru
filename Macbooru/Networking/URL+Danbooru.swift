import Foundation

extension URL {
    static func makeDanbooruURL(_ string: String?) -> URL? {
        guard let string = string, !string.isEmpty else { return nil }
        if let url = URL(string: string), url.scheme != nil {
            return url
        }

        var path = string
        if !path.hasPrefix("/") { path = "/" + path }
        return URL(string: path, relativeTo: DanbooruConfig.resolvedBaseURL())?.absoluteURL
    }
}
