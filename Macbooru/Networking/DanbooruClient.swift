import Foundation
import os

struct DanbooruConfig {
    var baseURL: URL = URL(string: "https://danbooru.donmai.us")!
    var apiKey: String? = nil
    var username: String? = nil
}

private extension Logger {
    static let network = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Macbooru",
        category: "Network"
    )
}

private extension String {
    var urlEncoded: String {
        let allowed = CharacterSet(charactersIn: "-._* ").union(.alphanumerics)
        return addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: " ", with: "+")
            ?? self
    }
}

enum APIError: Error {
    case invalidResponse
    case serverError(Int)
    case decoding(Error)
    case missingCredentials
}

final class DanbooruClient {
    private let session: URLSession
    private let config: DanbooruConfig
    private let logger = Logger.network
    private static let iso8601WithFS: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso8601NoFS: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            if let d = DanbooruClient.iso8601WithFS.date(from: s) { return d }
            if let d = DanbooruClient.iso8601NoFS.date(from: s) { return d }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ISO8601 date: \(s)"
                )
            )
        }
        return decoder
    }

    init(
        session: URLSession = {
            let cfg = URLSessionConfiguration.default
            cfg.httpMaximumConnectionsPerHost = 3
            cfg.waitsForConnectivity = true
            cfg.timeoutIntervalForRequest = 30
            cfg.timeoutIntervalForResource = 60
            cfg.httpAdditionalHeaders = [
                "User-Agent":
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                "Accept": "application/json",
            ]
            return URLSession(configuration: cfg)
        }(), config: DanbooruConfig = DanbooruConfig()
    ) {
        self.session = session
        self.config = config
    }

    func fetchPosts(tags: String? = nil, page: Int = 1, limit: Int = 20) async throws -> [Post] {
        var comps = URLComponents(
            url: config.baseURL.appendingPathComponent("/posts.json"),
            resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let tags, !tags.isEmpty { queryItems.append(URLQueryItem(name: "tags", value: tags)) }
        comps.queryItems = queryItems

        var req = URLRequest(url: comps.url!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        req.timeoutInterval = 30
        logger.debug(
            "GET /posts page=\(page, privacy: .public) limit=\(limit, privacy: .public) tags=\(tags ?? "∅", privacy: .public)"
        )
        if let user = config.username, let key = config.apiKey {
            let authString = "\(user):\(key)".data(using: .utf8)!.base64EncodedString()
            req.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            logger.error("GET /posts failed status=\(http.statusCode, privacy: .public)")
            throw APIError.serverError(http.statusCode)
        }
        logger.debug(
            "GET /posts succeeded status=\(http.statusCode, privacy: .public) bytes=\(data.count, privacy: .public)"
        )

        let decoder = DanbooruClient.makeDecoder()
        do {
            return try decoder.decode([Post].self, from: data)
        } catch {
            logger.error("Decoding posts failed: \(error.localizedDescription, privacy: .public)")
            throw APIError.decoding(error)
        }
    }

    func fetchTags(prefix: String, limit: Int = 10) async throws -> [Tag] {
        guard !prefix.isEmpty else { return [] }
        var comps = URLComponents(
            url: config.baseURL.appendingPathComponent("/tags.json"), resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            URLQueryItem(name: "search[name_matches]", value: prefix + "*"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "search[order]", value: "count"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        logger.debug(
            "GET /tags prefix=\(prefix, privacy: .public) limit=\(limit, privacy: .public)"
        )
        if let user = config.username, let key = config.apiKey {
            let authString = "\(user):\(key)".data(using: .utf8)!.base64EncodedString()
            req.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            logger.error("GET /tags failed status=\(status, privacy: .public)")
            throw APIError.invalidResponse
        }
        logger.debug(
            "GET /tags succeeded status=\(http.statusCode, privacy: .public) bytes=\(data.count, privacy: .public)"
        )
        let decoder = DanbooruClient.makeDecoder()
        return try decoder.decode([Tag].self, from: data)
    }

    func favorite(postID: Int) async throws {
        var req = URLRequest(url: config.baseURL.appendingPathComponent("/favorites.json"))
        req.httpMethod = "POST"
        req.httpBody = "post_id=\(postID)".data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        req.timeoutInterval = 30
        try applyAuth(to: &req)
        logger.debug("POST /favorites for post=\(postID, privacy: .public)")
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            logger.error("POST /favorites failed status=\(http.statusCode, privacy: .public)")
            throw APIError.serverError(http.statusCode)
        }
    }

    func unfavorite(postID: Int) async throws {
        var req = URLRequest(
            url: config.baseURL.appendingPathComponent("/favorites/\(postID).json")
        )
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        try applyAuth(to: &req)
        logger.debug("DELETE /favorites/\(postID, privacy: .public)")
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            logger.error("DELETE /favorites failed status=\(http.statusCode, privacy: .public)")
            throw APIError.serverError(http.statusCode)
        }
    }

    func vote(postID: Int, score: Int) async throws {
        var req = URLRequest(
            url: config.baseURL.appendingPathComponent("/posts/\(postID)/votes.json")
        )
        req.httpMethod = "POST"
        req.httpBody = "score=\(score)".data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        try applyAuth(to: &req)
        logger.debug("POST /posts/\(postID, privacy: .public)/votes score=\(score, privacy: .public)")
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            logger.error("POST /votes failed status=\(http.statusCode, privacy: .public)")
            throw APIError.serverError(http.statusCode)
        }
    }

    func fetchComments(postID: Int, limit: Int = 40) async throws -> [Comment] {
        var comps = URLComponents(
            url: config.baseURL.appendingPathComponent("/comments.json"), resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            URLQueryItem(name: "search[post_id]", value: String(postID)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        logger.debug("GET /comments post=\(postID, privacy: .public)")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            logger.error("GET /comments failed status=\(http.statusCode, privacy: .public)")
            throw APIError.serverError(http.statusCode)
        }
        let decoder = DanbooruClient.makeDecoder()
        return try decoder.decode([Comment].self, from: data)
    }

    func createComment(postID: Int, body: String) async throws -> Comment {
        var req = URLRequest(url: config.baseURL.appendingPathComponent("/comments.json"))
        req.httpMethod = "POST"
        req.httpBody = "comment[post_id]=\(postID)&comment[body]=\(body.urlEncoded)".data(
            using: .utf8
        )
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        try applyAuth(to: &req)
        logger.debug("POST /comments post=\(postID, privacy: .public)")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            logger.error("POST /comments failed status=\(http.statusCode, privacy: .public)")
            throw APIError.serverError(http.statusCode)
        }
        let decoder = DanbooruClient.makeDecoder()
        return try decoder.decode(Comment.self, from: data)
    }

    private func applyAuth(to request: inout URLRequest) throws {
        guard let user = config.username, let key = config.apiKey else {
            throw APIError.missingCredentials
        }
        let authString = "\(user):\(key)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(authString)", forHTTPHeaderField: "Authorization")
    }
}
