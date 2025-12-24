import Combine
import SwiftUI

@MainActor
final class PostDetailViewModel: ObservableObject {
    // MARK: - Dependencies
    private var dependencies: AppDependencies
    // Callback to notify View about auth failures (since Store is in Environment)
    var onAuthenticationFailure: ((String) -> Void)?

    // MARK: - State
    let post: Post
    
    @Published var comments: [Comment] = []
    @Published var isLoadingComments = false
    @Published var commentsError: String? = nil
    @Published var newComment: String = ""
    @Published var isSubmittingComment = false
    
    // Pagination
    @Published var commentsPage: Int = 1
    @Published var hasMoreComments: Bool = true
    @Published var isLoadingMoreComments: Bool = false
    private let commentsPageSize = 40

    // Interaction
    @Published var isInteractionInProgress = false
    @Published var isFavorited: Bool? = nil
    @Published var favoriteCount: Int? = nil
    @Published var upScore: Int? = nil
    @Published var downScore: Int? = nil
    @Published var lastVoteScore: Int? = nil
    
    // Downloads / Actions
    @Published var isDownloading = false
    @Published var saveMessage: String? = nil
    
    // Credentials State (injected from View)
    var hasCredentials: Bool = false

    // MARK: - Init
    init(post: Post, dependencies: AppDependencies = .makePreview()) {
        self.post = post
        self.dependencies = dependencies
    }
    
    func inject(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // MARK: - Computed
    var bestImageCandidates: [URL] {
        [post.largeURL, post.fileURL, post.previewURL].compactMap { $0 }
    }
    
    var pageURL: URL {
        URL(string: "https://danbooru.donmai.us/posts/\(post.id)")!
    }
    
    var currentFavoriteState: Bool {
        isFavorited ?? post.isFavorited ?? false
    }

    // MARK: - Logic
    
    func syncPostState() {
        isFavorited = post.isFavorited
        favoriteCount = post.favCount
        upScore = post.upScore
        downScore = post.downScore
    }
    
    func refreshComments() async {
        guard !isLoadingComments else { return }
        commentsPage = 1
        hasMoreComments = true
        comments.removeAll()
        await loadComments(page: 1, replace: true)
    }
    
    func loadMoreComments() async {
        guard hasMoreComments, !isLoadingMoreComments else { return }
        let nextPage = commentsPage + 1
        await loadComments(page: nextPage, replace: false)
    }
    
    private func loadComments(page: Int, replace: Bool) async {
        if replace {
            isLoadingComments = true
        } else {
            isLoadingMoreComments = true
        }
        commentsError = nil
        do {
            let items = try await dependencies.comments.load(
                postID: post.id, page: page, limit: commentsPageSize)
            if replace {
                comments = items
            } else {
                comments.append(contentsOf: items)
            }
            comments.sort(by: commentOrder)
            commentsPage = page
            hasMoreComments = items.count == commentsPageSize
        } catch {
            commentsError = commentErrorMessage(for: error)
        }
        isLoadingComments = false
        isLoadingMoreComments = false
    }
    
    func submitComment() async {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSubmittingComment else { return }
        
        guard hasCredentials else {
             commentsError = "Authenticate with Danbooru (API key + username) to use this action."
             return
        }

        isSubmittingComment = true
        commentsError = nil
        do {
            let comment = try await dependencies.comments.create(postID: post.id, body: trimmed)
            newComment = ""
            comments.append(comment)
            comments.sort(by: commentOrder)
            showToast("Comment posted")
        } catch {
            commentsError = commentErrorMessage(for: error)
        }
        isSubmittingComment = false
    }
    
    func performFavorite(add: Bool) async {
        guard hasCredentials else {
            showToast("Добавьте учетные данные Danbooru в Настройках")
            return
        }
        guard !isInteractionInProgress else { return }
        isInteractionInProgress = true
        defer { isInteractionInProgress = false }
        do {
            if add {
                try await dependencies.favoritePost.favorite(postID: post.id)
                updateFavoriteState(isFavorited: true)
                showToast("Добавлено в избранное")
            } else {
                try await dependencies.favoritePost.unfavorite(postID: post.id)
                updateFavoriteState(isFavorited: false)
                showToast("Удалено из избранного")
            }
        } catch {
            handleAuthErrorIfNeeded(error)
            showToast(commentErrorMessage(for: error))
        }
    }
    
    func performVote(score: Int) async {
        guard hasCredentials else {
            showToast("Добавьте учетные данные Danbooru в Настройках")
            return
        }
        guard !isInteractionInProgress else { return }
        isInteractionInProgress = true
        defer { isInteractionInProgress = false }
        do {
            try await dependencies.votePost.vote(postID: post.id, score: score)
            let message = score >= 0 ? "Оценка +1 отправлена" : "Оценка -1 отправлена"
            updateVoteState(score: score)
            lastVoteScore = score
            showToast(message)
        } catch {
            handleAuthErrorIfNeeded(error)
            showToast(commentErrorMessage(for: error))
        }
    }
    
    func downloadBestImage() async {
        guard !isDownloading else { return }
        guard let url = bestImageCandidates.first else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fm = FileManager.default
            let downloads = try fm.url(
                for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let folder = downloads.appendingPathComponent("Macbooru", isDirectory: true)
            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let filename =
                url.lastPathComponent.isEmpty ? "post-\(post.id).jpg" : url.lastPathComponent
            let dest = folder.appendingPathComponent(filename)
            try data.write(to: dest)
            showToast("Saved to Downloads/Macbooru")
        } catch {
            showToast("Save failed: \(error.localizedDescription)")
        }
    }
    
    func copyImageToPasteboard() async {
        #if os(macOS)
            guard let url = post.fileURL ?? post.largeURL ?? post.previewURL else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = NSImage(data: data) else {
                    showToast("Cannot decode image")
                    return
                }
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([image])
                showToast("Image copied")
            } catch {
                showToast("Copy failed: \(error.localizedDescription)")
            }
        #endif
    }
    
    // MARK: - Helpers

    func showToast(_ message: String) {
        withAnimation { saveMessage = message }
        // Auto-hide logic moved here
        Task {
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            withAnimation {
                if self.saveMessage == message { // Check if message hasn't changed
                    self.saveMessage = nil
                }
            }
        }
    }

    private func commentOrder(_ lhs: Comment, _ rhs: Comment) -> Bool {
        let lhsDate = lhs.createdAt ?? .distantPast
        let rhsDate = rhs.createdAt ?? .distantPast
        return lhsDate < rhsDate
    }

    private func updateFavoriteState(isFavorited newValue: Bool) {
        let previous = isFavorited ?? post.isFavorited ?? false
        isFavorited = newValue
        var base = favoriteCount ?? post.favCount ?? 0
        if newValue && !previous {
            base += 1
        } else if !newValue && previous {
            base = max(0, base - 1)
        }
        favoriteCount = base
    }

    private func updateVoteState(score: Int) {
        if score >= 0 {
            let current = upScore ?? post.upScore ?? 0
            upScore = current + score
        } else {
            let current = downScore ?? post.downScore ?? 0
            downScore = current + abs(score)
        }
    }

    private func handleAuthErrorIfNeeded(_ error: Error) {
        if case APIError.serverError(let code) = error, code == 401 || code == 403 {
            onAuthenticationFailure?("Недействительные учетные данные Danbooru")
        }
        if let apiError = error as? APIError, case .missingCredentials = apiError {
             onAuthenticationFailure?("Укажите учетные данные Danbooru")
        }
    }

    private func commentErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .missingCredentials:
                return "Authenticate with Danbooru (API key + username) to use this action."
            case .serverError(let code):
                if code == 401 || code == 403 {
                    return "Недостаточно прав или неверные учетные данные."
                }
                return "Server error (status \(code)). Try again later."
            case .decoding(let underlying):
                return "Failed to parse server response: \(underlying.localizedDescription)"
            case .invalidResponse:
                return "Invalid server response."
            }
        }
        if let urlError = error as? URLError {
            return "Network error: \(urlError.localizedDescription)"
        }
        return error.localizedDescription
    }
}

