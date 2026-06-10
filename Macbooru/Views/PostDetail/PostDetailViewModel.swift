import Combine
import SwiftUI

@MainActor
final class PostDetailViewModel: ObservableObject {
    // MARK: - Dependencies
    private var dependencies: AppDependencies
    // Callback to notify View about auth failures (since Store is in Environment)
    var onAuthenticationFailure: ((String) -> Void)?

    // MARK: - State
    private(set) var post: Post
    
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
        [post.previewURL, post.largeURL, post.fileURL].compactMap { $0 }
    }
    
    var pageURL: URL {
        DanbooruConfig.resolvedBaseURL().appendingPathComponent("posts/\(post.id)")
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

    func replacePost(_ newPost: Post) {
        post = newPost
        syncPostState()
        lastVoteScore = nil
        comments = []
        commentsPage = 1
        hasMoreComments = true
        commentsError = nil
        newComment = ""
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
             commentsError = L10n.Error.commentAuthRequired
             return
        }

        isSubmittingComment = true
        commentsError = nil
        do {
            let comment = try await dependencies.comments.create(postID: post.id, body: trimmed)
            newComment = ""
            comments.append(comment)
            comments.sort(by: commentOrder)
            showToast(L10n.Toast.commentSent)
        } catch {
            commentsError = commentErrorMessage(for: error)
        }
        isSubmittingComment = false
    }
    
    func performFavorite(add: Bool) async {
        guard hasCredentials else {
            showToast(L10n.Toast.addCredentials)
            return
        }
        guard !isInteractionInProgress else { return }
        isInteractionInProgress = true
        defer { isInteractionInProgress = false }
        do {
            if add {
                try await dependencies.favoritePost.favorite(postID: post.id)
                updateFavoriteState(isFavorited: true)
                showToast(L10n.Toast.addedFavorite)
            } else {
                try await dependencies.favoritePost.unfavorite(postID: post.id)
                updateFavoriteState(isFavorited: false)
                showToast(L10n.Toast.removedFavorite)
            }
        } catch {
            handleAuthErrorIfNeeded(error)
            showToast(commentErrorMessage(for: error))
        }
    }
    
    func performVote(score: Int) async {
        guard hasCredentials else {
            showToast(L10n.Toast.addCredentials)
            return
        }
        guard !isInteractionInProgress else { return }
        isInteractionInProgress = true
        defer { isInteractionInProgress = false }
        do {
            try await dependencies.votePost.vote(postID: post.id, score: score)
            let message = score >= 0 ? L10n.Toast.voteUpSent : L10n.Toast.voteDownSent
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
        guard let url = post.fileURL ?? post.largeURL ?? post.previewURL else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let data = try await ThrottledImageLoader.shared.loadData(url)
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
            showToast(L10n.Toast.savedToDownloads)
        } catch {
            showToast(L10n.Toast.saveFailed(error.localizedDescription))
        }
    }
    
    func copyImageToPasteboard() async {
        #if os(macOS)
            guard let url = post.fileURL ?? post.largeURL ?? post.previewURL else { return }
            do {
                let data = try await ThrottledImageLoader.shared.loadData(url)
                guard let image = NSImage(data: data) else {
                    showToast(L10n.Toast.decodeImageFailed)
                    return
                }
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([image])
                showToast(L10n.Toast.imageCopied)
            } catch {
                showToast(L10n.Toast.copyFailed(error.localizedDescription))
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
            onAuthenticationFailure?(L10n.Error.invalidCredentials)
        }
        if let apiError = error as? APIError, case .missingCredentials = apiError {
             onAuthenticationFailure?(L10n.Error.credentialsRequired)
        }
    }

    private func commentErrorMessage(for error: Error) -> String {
        NetworkErrorMessage.friendly(for: error)
    }
}
