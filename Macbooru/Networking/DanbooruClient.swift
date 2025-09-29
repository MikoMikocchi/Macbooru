import Foundation

struct DanbooruConfig {
    var baseURL: URL = URL(string: "https://danbooru.donmai.us")!
    var apiKey: String? = nil
    var username: String? = nil
}

enum APIError: Error {
    case invalidResponse
    case serverError(Int)
    case decoding(Error)
}

final class DanbooruClient {
    private let session: URLSession
    private let config: DanbooruConfig

    init(session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpMaximumConnectionsPerHost = 3
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept": "application/json"
        ]
        return URLSession(configuration: cfg)
    }(), config: DanbooruConfig = DanbooruConfig()) {
        self.session = session
        self.config = config
    }

    func fetchPosts(tags: String? = nil, page: Int = 1, limit: Int = 20) async throws -> [Post] {
        var comps = URLComponents(url: config.baseURL.appendingPathComponent("/posts.json"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let tags, !tags.isEmpty { queryItems.append(URLQueryItem(name: "tags", value: tags)) }
        comps.queryItems = queryItems

        var req = URLRequest(url: comps.url!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        req.timeoutInterval = 30
        if let user = config.username, let key = config.apiKey {
            let authString = "\(user):\(key)".data(using: .utf8)!.base64EncodedString()
            req.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.serverError(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([Post].self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
