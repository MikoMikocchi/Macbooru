import Foundation

/// Type-safe localization layer backed by `Localizable.xcstrings`.
enum L10n {
    private static func tr(_ key: String.LocalizationValue) -> String {
        String(localized: key, table: "Localizable")
    }

    private static func tr(_ key: String.LocalizationValue, _ args: CVarArg...) -> String {
        let format = String(localized: key, table: "Localizable")
        return String(format: format, locale: Locale.current, arguments: args)
    }

    enum Grid {
        static var postsTitle: String { tr("grid.postsTitle") }
        static var refresh: String { tr("grid.refresh") }
        static var pageControls: String { tr("grid.pageControls") }
        static var errorTitle: String { tr("grid.errorTitle") }
        static var retry: String { tr("grid.retry") }
        static func backToPage(_ page: Int) -> String { tr("grid.backToPage", page) }
        static func loadFailed(_ detail: String) -> String { tr("grid.loadFailed", detail) }
        static var unableFindLastPage: String { tr("grid.unableFindLastPage") }
    }

    enum Sidebar {
        enum Search {
            static var title: String { tr("sidebar.search.title") }
            static var subtitle: String { tr("sidebar.search.subtitle") }
            static var placeholder: String { tr("sidebar.search.placeholder") }
            static var button: String { tr("sidebar.search.button") }
        }

        static var save: String { tr("sidebar.save") }
        static var clear: String { tr("sidebar.clear") }
        static var keyboardHintFull: String { tr("sidebar.keyboardHintFull") }
        static var keyboardHintShort: String { tr("sidebar.keyboardHintShort") }

        enum Favorites {
            static var title: String { tr("sidebar.favorites.title") }
            static var help: String { tr("sidebar.favorites.help") }
            static var subtitleOwn: String { tr("sidebar.favorites.subtitleOwn") }
            static func subtitleUser(_ name: String) -> String { tr("sidebar.favorites.subtitleUser", name) }
        }

        static var savedSearches: String { tr("sidebar.savedSearches") }
        static var recentSearches: String { tr("sidebar.recentSearches") }
        static var pin: String { tr("sidebar.pin") }
        static var unpin: String { tr("sidebar.unpin") }
        static var delete: String { tr("sidebar.delete") }
        static var sort: String { tr("sidebar.sort") }
        static var poolID: String { tr("sidebar.poolID") }
        static var rating: String { tr("sidebar.rating") }
        static var tileSize: String { tr("sidebar.tileSize") }
        static var pageSize: String { tr("sidebar.pageSize") }
        static var blurNSFW: String { tr("sidebar.blurNSFW") }
    }

    enum Sort {
        static func label(for mode: SortMode) -> String {
            switch mode {
            case .recent: tr("sort.recent")
            case .newest: tr("sort.newest")
            case .oldest: tr("sort.oldest")
            case .rank: tr("sort.rank")
            case .score: tr("sort.score")
            case .favs: tr("sort.favs")
            case .random: tr("sort.random")
            }
        }
    }

    enum RatingLabels {
        static func display(for rating: Rating) -> String {
            switch rating {
            case .any: tr("rating.any")
            case .g, .s, .q, .e: rating.rawValue.uppercased()
            }
        }
    }

    enum TileSizeLabels {
        static func title(for size: TileSize) -> String {
            switch size {
            case .small: tr("tileSize.small")
            case .medium: tr("tileSize.medium")
            case .large: tr("tileSize.large")
            }
        }
    }

    enum Commands {
        static var navigation: String { tr("commands.navigation") }
        static var search: String { tr("commands.search") }
        static var prevPage: String { tr("commands.prevPage") }
        static var nextPage: String { tr("commands.nextPage") }
        static var prevPost: String { tr("commands.prevPost") }
        static var nextPost: String { tr("commands.nextPost") }
        static var focusSearch: String { tr("commands.focusSearch") }
        static var pageSize15: String { tr("commands.pageSize15") }
        static var pageSize30: String { tr("commands.pageSize30") }
        static var pageSize60: String { tr("commands.pageSize60") }
    }

    enum PostDetail {
        static func title(postID: Int) -> String { tr("postDetail.title", postID) }
        static var loading: String { tr("postDetail.loading") }
        static var unavailable: String { tr("postDetail.unavailable") }
        static var inProgress: String { tr("postDetail.inProgress") }
        static var download: String { tr("postDetail.download") }
        static var saving: String { tr("postDetail.saving") }
        static var info: String { tr("postDetail.info") }
        static var id: String { tr("postDetail.id") }
        static var rating: String { tr("postDetail.rating") }
        static var favCount: String { tr("postDetail.favCount") }
        static var favorite: String { tr("postDetail.favorite") }
        static var yes: String { tr("postDetail.yes") }
        static var no: String { tr("postDetail.no") }
        static var upvotes: String { tr("postDetail.upvotes") }
        static var downvotes: String { tr("postDetail.downvotes") }
        static var dimensions: String { tr("postDetail.dimensions") }
        static var created: String { tr("postDetail.created") }
        static var openSource: String { tr("postDetail.openSource") }
        static var tags: String { tr("postDetail.tags") }
        static var tagArtist: String { tr("postDetail.tagArtist") }
        static var tagCopyright: String { tr("postDetail.tagCopyright") }
        static var tagCharacter: String { tr("postDetail.tagCharacter") }
        static var tagGeneral: String { tr("postDetail.tagGeneral") }
        static var tagMeta: String { tr("postDetail.tagMeta") }
        static var noTags: String { tr("postDetail.noTags") }
        static var copySectionTags: String { tr("postDetail.copySectionTags") }
        static var tagHelp: String { tr("postDetail.tagHelp") }
        static func tagAccessibility(_ tag: String) -> String { tr("postDetail.tagAccessibility", tag) }
        static var tagAccessibilityHint: String { tr("postDetail.tagAccessibilityHint") }
        static var comments: String { tr("postDetail.comments") }
        static var loadingComments: String { tr("postDetail.loadingComments") }
        static var loadMore: String { tr("postDetail.loadMore") }
        static var noComments: String { tr("postDetail.noComments") }
        static var addComment: String { tr("postDetail.addComment") }
        static var send: String { tr("postDetail.send") }
        static var commentHint: String { tr("postDetail.commentHint") }
        static var commentRules: String { tr("postDetail.commentRules") }
        static var commentCredentials: String { tr("postDetail.commentCredentials") }
        static func commentFrom(_ author: String) -> String { tr("postDetail.commentFrom", author) }
        static var anonymous: String { tr("postDetail.anonymous") }
        static var ugoira: String { tr("postDetail.ugoira") }
        static var ugoiraHint: String { tr("postDetail.ugoiraHint") }
        static var openPostPage: String { tr("postDetail.openPostPage") }
        static var openLarge: String { tr("postDetail.openLarge") }
        static var openOriginal: String { tr("postDetail.openOriginal") }
        static var open: String { tr("postDetail.open") }
        static var openHint: String { tr("postDetail.openHint") }
        static var copyPostURL: String { tr("postDetail.copyPostURL") }
        static var copyImage: String { tr("postDetail.copyImage") }
        static var copyOriginalURL: String { tr("postDetail.copyOriginalURL") }
        static var copySourceURL: String { tr("postDetail.copySourceURL") }
        static var copyTags: String { tr("postDetail.copyTags") }
        static var copy: String { tr("postDetail.copy") }
        static var copyHint: String { tr("postDetail.copyHint") }
        static var removeFavorite: String { tr("postDetail.removeFavorite") }
        static var addFavorite: String { tr("postDetail.addFavorite") }
        static var voteUp: String { tr("postDetail.voteUp") }
        static var voteDown: String { tr("postDetail.voteDown") }
        static var actions: String { tr("postDetail.actions") }
        static var actionsHint: String { tr("postDetail.actionsHint") }
        static var favAndVote: String { tr("postDetail.favAndVote") }
        static var credentialsRequired: String { tr("postDetail.credentialsRequired") }
        static var showDownloads: String { tr("postDetail.showDownloads") }
        static var more: String { tr("postDetail.more") }
        static var moreHint: String { tr("postDetail.moreHint") }
        static var resetZoom: String { tr("postDetail.resetZoom") }
        static var prevPost: String { tr("postDetail.prevPost") }
        static var nextPost: String { tr("postDetail.nextPost") }
        static var downloadBest: String { tr("postDetail.downloadBest") }
        static var fit: String { tr("postDetail.fit") }
        static var zoomIn: String { tr("postDetail.zoomIn") }
        static var zoomOut: String { tr("postDetail.zoomOut") }
        static var center: String { tr("postDetail.center") }
    }

    enum PostTile {
        static var sensitiveContent: String { tr("postTile.sensitiveContent") }
        static var openOriginalBrowser: String { tr("postTile.openOriginalBrowser") }
        static var openLargeBrowser: String { tr("postTile.openLargeBrowser") }
        static var openPreviewBrowser: String { tr("postTile.openPreviewBrowser") }
        static var copyLargeURL: String { tr("postTile.copyLargeURL") }
        static var copyPreviewURL: String { tr("postTile.copyPreviewURL") }
    }

    enum Toast {
        static var tagsCopied: String { tr("toast.tagsCopied") }
        static func tagCopied(_ tag: String) -> String { tr("toast.tagCopied", tag) }
        static var originalURLCopied: String { tr("toast.originalURLCopied") }
        static var postURLCopied: String { tr("toast.postURLCopied") }
        static var sourceURLCopied: String { tr("toast.sourceURLCopied") }
        static func downloadsFolderFailed(_ detail: String) -> String {
            tr("toast.downloadsFolderFailed", detail)
        }
        static var commentSent: String { tr("toast.commentSent") }
        static var addCredentials: String { tr("toast.addCredentials") }
        static var addedFavorite: String { tr("toast.addedFavorite") }
        static var removedFavorite: String { tr("toast.removedFavorite") }
        static var voteUpSent: String { tr("toast.voteUpSent") }
        static var voteDownSent: String { tr("toast.voteDownSent") }
        static var savedToDownloads: String { tr("toast.savedToDownloads") }
        static func saveFailed(_ detail: String) -> String { tr("toast.saveFailed", detail) }
        static var decodeImageFailed: String { tr("toast.decodeImageFailed") }
        static var imageCopied: String { tr("toast.imageCopied") }
        static func copyFailed(_ detail: String) -> String { tr("toast.copyFailed", detail) }
    }

    enum Settings {
        static var credentials: String { tr("settings.credentials") }
        static var baseURL: String { tr("settings.baseURL") }
        static var username: String { tr("settings.username") }
        static var apiKey: String { tr("settings.apiKey") }
        static var credentialsFootnote: String { tr("settings.credentialsFootnote") }
        static func verificationFailed(_ detail: String) -> String { tr("settings.verificationFailed", detail) }
        static var clear: String { tr("settings.clear") }
        static var save: String { tr("settings.save") }
        static var credentialsSaved: String { tr("settings.credentialsSaved") }
        static var credentialsCleared: String { tr("settings.credentialsCleared") }
        static func saveFailed(_ detail: String) -> String { tr("settings.saveFailed", detail) }
        static var credentialsDeleted: String { tr("settings.credentialsDeleted") }
        static func deleteFailed(_ detail: String) -> String { tr("settings.deleteFailed", detail) }
        static var imageCache: String { tr("settings.imageCache") }
        static var maxCacheSize: String { tr("settings.maxCacheSize") }
        static func currentLimit(_ mb: Int) -> String { tr("settings.currentLimit", mb) }
        static func cacheUsage(_ mb: String) -> String { tr("settings.cacheUsage", mb) }
        static var apply: String { tr("settings.apply") }
        static var cacheLimitUpdated: String { tr("settings.cacheLimitUpdated") }
        static var cacheCleared: String { tr("settings.cacheCleared") }
        static var general: String { tr("settings.general") }
        static var infiniteScroll: String { tr("settings.infiniteScroll") }
        static var infiniteScrollSubtitle: String { tr("settings.infiniteScrollSubtitle") }
        static var lowPerformance: String { tr("settings.lowPerformance") }
        static var lowPerformanceSubtitle: String { tr("settings.lowPerformanceSubtitle") }
        static var autoRefresh: String { tr("settings.autoRefresh") }
        static var autoRefreshSubtitle: String { tr("settings.autoRefreshSubtitle") }
        static var keyboardHints: String { tr("settings.keyboardHints") }
        static var keyboardHintsSubtitle: String { tr("settings.keyboardHintsSubtitle") }
        static var blurNSFW: String { tr("settings.blurNSFW") }
        static var blurNSFWSubtitle: String { tr("settings.blurNSFWSubtitle") }
        static var more: String { tr("settings.more") }
        static var linksAndTools: String { tr("settings.linksAndTools") }
        static var apiDocs: String { tr("settings.apiDocs") }
        static var openKeychain: String { tr("settings.openKeychain") }
        static var keychainSubtitle: String { tr("settings.keychainSubtitle") }
        static var github: String { tr("settings.github") }
        static var status: String { tr("settings.status") }
        static var allGood: String { tr("settings.allGood") }
        static func registered(_ date: String) -> String { tr("settings.registered", date) }
    }

    enum Error {
        static var noInternet: String { tr("error.noInternet") }
        static func network(_ detail: String) -> String { tr("error.network", detail) }
        static var missingCredentials: String { tr("error.missingCredentials") }
        static var accessDenied: String { tr("error.accessDenied") }
        static var rateLimit: String { tr("error.rateLimit") }
        static func serverStatus(_ code: Int) -> String { tr("error.serverStatus", code) }
        static var invalidResponse: String { tr("error.invalidResponse") }
        static var decoding: String { tr("error.decoding") }
        static var invalidCredentials: String { tr("error.invalidCredentials") }
        static var credentialsRequired: String { tr("error.credentialsRequired") }
        static var commentAuthRequired: String { tr("error.commentAuthRequired") }

        static func message(for error: Swift.Error) -> String {
            if let urlError = error as? URLError {
                if urlError.code == .notConnectedToInternet {
                    return noInternet
                }
                return network(urlError.localizedDescription)
            }
            if let apiError = error as? APIError {
                return apiError.localizedDescription
            }
            return error.localizedDescription
        }
    }
}
