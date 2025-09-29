import Foundation

extension URL {
    private static let danbooruBase = URL(string: "https://danbooru.donmai.us")!

    /// Строит корректный URL для строк, которые могут быть абсолютными или относительными путями Danbooru
    static func makeDanbooruURL(_ string: String?) -> URL? {
        guard let string = string, !string.isEmpty else { return nil }
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        // Относительный путь — дополним базовым URL
        var path = string
        if !path.hasPrefix("/") { path = "/" + path }
        return URL(string: path, relativeTo: danbooruBase)?.absoluteURL
    }
}
