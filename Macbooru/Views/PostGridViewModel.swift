import Combine
import os
import SwiftUI

private extension Logger {
    static let postGrid = Logger(subsystem: "Macbooru", category: "PostGrid")
}

@MainActor
final class PostGridViewModel: ObservableObject {
    // MARK: - Dependencies

    let search: SearchState
    private var dependencies: AppDependencies
    private let logger = Logger.postGrid

    // MARK: - Published State

    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var nextPageInFlight: Int? = nil
    @Published var lastErrorMessage: String? = nil
    @Published var originPage: Int? = nil
    @Published var showBackToOrigin: Bool = false
    @Published var knownMaxPage: Int? = nil
    @Published var isFindingLast: Bool = false

    // MARK: - Private State

    private var replaceRequestID: Int = 0
    private var loadGeneration: Int = 0
    private var loadTask: Task<Void, Never>?
    private let windowRadius: Int = 2
    private let infiniteScrollWindowPages: Int = 3

    // MARK: - Init

    init(search: SearchState, dependencies: AppDependencies = .makePreview()) {
        self.search = search
        self.dependencies = dependencies
    }

    func inject(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // MARK: - Computed

    var pagesWindowArray: [Int] {
        let current = search.page
        let start = max(1, current - windowRadius)
        let end = max(start, current + windowRadius)
        return Array(start...end)
    }

    // MARK: - Search / Refresh

    func handleSearchTriggerChange() {
        loadTask?.cancel()
        knownMaxPage = nil
        originPage = nil
        showBackToOrigin = false
        hasMore = true
        isLoadingMore = false
        nextPageInFlight = nil
        refreshAction()
    }

    func refreshAction() {
        loadTask?.cancel()
        loadTask = Task { await refresh() }
    }

    @MainActor
    func refresh() async {
        search.page = 1
        posts.removeAll()
        hasMore = true
        isLoadingMore = false
        nextPageInFlight = nil
        await load(page: 1, replace: true)
    }

    func scheduleLoad(page: Int, replace: Bool) {
        if replace {
            loadTask?.cancel()
        }
        loadTask = Task { await load(page: page, replace: replace) }
    }

    func scheduleInitialLoad() {
        loadTask?.cancel()
        loadTask = Task { await load(page: 1, replace: true) }
    }

    // MARK: - Pagination Actions

    func prevAction() {
        guard !search.infiniteScrollEnabled else { return }
        guard !isLoading, search.page > 1 else { return }
        scheduleLoad(page: max(1, search.page - 1), replace: true)
    }

    func nextAction() {
        guard !search.infiniteScrollEnabled else { return }
        guard !isLoading else { return }
        scheduleLoad(page: search.page + 1, replace: true)
    }

    func selectPage(_ page: Int) {
        guard !isLoading else { return }
        scheduleLoad(page: max(1, page), replace: true)
    }

    func goFirst() {
        guard !isLoading else { return }
        if originPage == nil { originPage = search.page }
        scheduleLoad(page: 1, replace: true)
        if let origin = originPage, origin > 3 {
            withAnimation { showBackToOrigin = true }
        }
    }

    func goLast() {
        guard !isLoading else { return }
        if originPage == nil { originPage = search.page }
        loadTask?.cancel()
        loadTask = Task {
            if let known = knownMaxPage {
                await load(page: known, replace: true)
                if let origin = originPage, known - origin >= 3 {
                    withAnimation { showBackToOrigin = true }
                }
            } else {
                isFindingLast = true
                if let last = await findLastPage() {
                    knownMaxPage = last
                    await load(page: last, replace: true)
                    if let origin = originPage, last - origin >= 3 {
                        withAnimation { showBackToOrigin = true }
                    }
                } else {
                    withAnimation { lastErrorMessage = "Unable to find last page" }
                }
                isFindingLast = false
            }
        }
    }

    func paginateByDrag(steps: Int, direction: Int) {
        guard !isLoading else { return }
        let target = max(1, search.page + direction * steps)
        if originPage == nil { originPage = search.page }
        scheduleLoad(page: target, replace: true)
        if let origin = originPage, abs(target - origin) >= 3 {
            withAnimation { showBackToOrigin = true }
        }
    }

    func backToOrigin() {
        guard let origin = originPage else { return }
        scheduleLoad(page: origin, replace: true)
        withAnimation {
            showBackToOrigin = false
            originPage = nil
        }
    }

    func loadMoreIfNeeded() {
        guard search.infiniteScrollEnabled else { return }
        guard hasMore, !isLoading, !isLoadingMore else { return }
        let candidate = search.page + 1
        if let inflight = nextPageInFlight, inflight >= candidate {
            return
        }
        nextPageInFlight = candidate
        logger.debug("Loading infinite scroll page \(candidate) (current=\(self.search.page))")
        loadTask = Task { await load(page: candidate, replace: false) }
    }

    // MARK: - Load

    @MainActor
    private func load(page: Int, replace: Bool = true) async {
        let generationSnapshot = loadGeneration
        let requestIDSnapshot: Int
        if replace {
            replaceRequestID &+= 1
            requestIDSnapshot = replaceRequestID
            loadGeneration &+= 1
            isLoading = true
        } else {
            requestIDSnapshot = replaceRequestID
            guard !isLoadingMore, hasMore else { return }
            isLoadingMore = true
            nextPageInFlight = page
        }
        defer {
            if replace {
                if requestIDSnapshot == replaceRequestID {
                    isLoading = false
                }
            } else {
                isLoadingMore = false
            }
            if !replace { nextPageInFlight = nil }
        }
        do {
            try Task.checkCancellation()
            let next = try await dependencies.searchPosts.execute(
                query: search.danbooruQuery,
                page: page,
                limit: search.pageSize
            )
            try Task.checkCancellation()
            if replace {
                guard requestIDSnapshot == replaceRequestID else { return }
            } else {
                guard generationSnapshot == loadGeneration else { return }
            }
            if replace {
                posts = next
            } else {
                posts.append(contentsOf: next)
                trimInfiniteScrollWindowIfNeeded()
            }

            hasMore = next.count == search.pageSize
            search.page = max(1, page)
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            if Task.isCancelled { return }
            if replace {
                guard requestIDSnapshot == replaceRequestID else { return }
            } else {
                guard generationSnapshot == loadGeneration else { return }
            }
            withAnimation {
                lastErrorMessage = "Не удалось загрузить посты: \(error.localizedDescription)"
            }
            if !replace {
                hasMore = false
            }
            logger.error("Failed to load posts for page \(page): \(error.localizedDescription)")
        }
    }

    private func trimInfiniteScrollWindowIfNeeded() {
        guard search.infiniteScrollEnabled else { return }
        let maxPosts = search.pageSize * infiniteScrollWindowPages
        guard posts.count > maxPosts else { return }
        posts.removeFirst(posts.count - maxPosts)
    }

    // MARK: - Find Last Page

    @MainActor
    func findLastPage() async -> Int? {
        if posts.count < search.pageSize { return max(1, search.page) }

        let limit = search.pageSize
        var low = max(1, search.page)
        var high = low + 1
        var requests = 0
        let maxRequests = 12

        func fetchCount(_ page: Int) async -> Int? {
            do {
                try Task.checkCancellation()
                let arr = try await dependencies.searchPosts.execute(
                    query: search.danbooruQuery, page: page, limit: limit)
                return arr.count
            } catch is CancellationError {
                return nil
            } catch let error as URLError where error.code == .cancelled {
                return nil
            } catch {
                logger.error("findLastPage fetch failed page=\(page): \(error.localizedDescription)")
                return nil
            }
        }

        while requests < maxRequests {
            requests += 1
            if let cnt = await fetchCount(high) {
                if cnt == 0 {
                    break
                } else if cnt < limit {
                    return high
                } else {
                    low = high
                    high = high + 8
                }
            } else {
                break
            }
        }

        if high <= low { high = low + 8 }

        var left = low
        var right = high
        var answer = low
        while left <= right && requests < maxRequests {
            let mid = (left + right) / 2
            requests += 1
            guard let cnt = await fetchCount(mid) else { break }
            if cnt == 0 {
                right = mid - 1
            } else if cnt < limit {
                return mid
            } else {
                answer = mid
                left = mid + 1
            }
        }
        return answer
    }
}
