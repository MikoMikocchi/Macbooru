//
//  ContentView.swift
//  Macbooru
//
//  Created by Михаил Мацкевич on 29.09.2025.
//

import SwiftData
import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct PostGridView: View {
    @ObservedObject var search: SearchState
    @Environment(\.appDependencies) private var dependencies
    // Простая пагинация: единый массив текущей страницы
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var nextPageInFlight: Int? = nil
    @State private var lastErrorMessage: String? = nil
    @State private var columns: [GridItem] = []
    @State private var originPage: Int? = nil
    @State private var showBackToOrigin: Bool = false
    @State private var knownMaxPage: Int? = nil
    @State private var isFindingLast: Bool = false
    private let gridSpacing: CGFloat = 24
    private let windowRadius: Int = 2

    #if os(macOS)
        // MARK: - Two-finger swipe support (trackpad) via local scrollWheel monitor
        private struct TrackpadSwipeMonitor: NSViewRepresentable {
            let onLeft: () -> Void
            let onRight: () -> Void

            func makeCoordinator() -> Coordinator { Coordinator(onLeft: onLeft, onRight: onRight) }

            func makeNSView(context: Context) -> NSView {
                let v = NSView()
                v.wantsLayer = true
                v.layer?.backgroundColor = .clear
                context.coordinator.installMonitor(attachedTo: v)
                return v
            }

            func updateNSView(_ nsView: NSView, context: Context) {
                context.coordinator.installMonitor(attachedTo: nsView)
            }

            final class Coordinator: NSObject {
                let onLeft: () -> Void
                let onRight: () -> Void
                private var eventMonitorScroll: Any?
                private var eventMonitorSwipe: Any?
                private weak var attachedView: NSView?
                private var lastTriggerTime: TimeInterval = 0

                init(onLeft: @escaping () -> Void, onRight: @escaping () -> Void) {
                    self.onLeft = onLeft
                    self.onRight = onRight
                }

                func installMonitor(attachedTo view: NSView) {
                    attachedView = view
                    if eventMonitorScroll == nil {
                        eventMonitorScroll = NSEvent.addLocalMonitorForEvents(
                            matching: .scrollWheel
                        ) { [weak self] event in
                            guard let self, let attached = self.attachedView else { return event }
                            guard event.window === attached.window else { return event }
                            let dx = event.scrollingDeltaX
                            let dy = event.scrollingDeltaY
                            let now = CFAbsoluteTimeGetCurrent()
                            if abs(dx) > abs(dy), abs(dx) > 10, now - lastTriggerTime > 0.25 {
                                lastTriggerTime = now
                                if dx < 0 { onLeft() } else { onRight() }
                            }
                            return event
                        }
                    }
                    if eventMonitorSwipe == nil {
                        eventMonitorSwipe = NSEvent.addLocalMonitorForEvents(matching: .swipe) {
                            [weak self] event in
                            guard let self, let attached = self.attachedView else { return event }
                            guard event.window === attached.window else { return event }
                            let dx = event.deltaX
                            let now = CFAbsoluteTimeGetCurrent()
                            if abs(dx) > 0.5, now - lastTriggerTime > 0.25 {
                                lastTriggerTime = now
                                if dx < 0 { onLeft() } else { onRight() }
                                return nil  // потребляем swipe-жест, но это не блокирует клики
                            }
                            return event
                        }
                    }
                }

                deinit {
                    if let m = eventMonitorScroll { NSEvent.removeMonitor(m) }
                    if let m = eventMonitorSwipe { NSEvent.removeMonitor(m) }
                }
            }
        }
    #endif

    var body: some View {
        PostsGridScroll(
            posts: posts,
            tileHeight: search.tileSize.height,
            columns: columns,
            gridSpacing: gridSpacing,
            isLoading: isLoading || isLoadingMore,
            layout: search.layout,
            infiniteEnabled: search.infiniteScrollEnabled,
            onReachedEnd: {
                guard search.infiniteScrollEnabled else { return }
                Task { await loadMoreIfNeeded() }
            }
        )
        #if os(macOS)
            .overlay(
                TrackpadSwipeMonitor(
                    onLeft: { nextAction() },
                    onRight: { prevAction() }
                )
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
        #endif

        .navigationTitle("Posts")
        .task { await load(page: 1, replace: true) }
        .onChange(of: search.tileSize) { _, _ in
            recomputeColumns()
        }
        .onChange(of: search.searchTrigger) { _, _ in
            knownMaxPage = nil
            originPage = nil
            showBackToOrigin = false
            hasMore = true
            isLoadingMore = false
            nextPageInFlight = nil
            refreshAction()
        }
        .onAppear { recomputeColumns() }
        #if os(macOS)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        // горизонтальный двухпальцевый свайп: влево/вправо, не мешаем вертикальному скроллу
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > 60, abs(dy) < 40 else { return }
                        if dx < 0 {
                            nextAction()
                        } else {
                            prevAction()
                        }
                    }
            )
        #endif
        // .focusedSceneValue(\.gridActions, GridActions(prev: prevAction, next: nextAction, refresh: refreshAction))
        .toolbar { ToolbarItem(placement: .primaryAction) { refreshButton } }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !search.infiniteScrollEnabled { paginationOverlay }
                if !search.infiniteScrollEnabled { backToOriginOverlay }
                errorOverlay
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }

    private var refreshButton: some View {
        Button(action: refreshAction) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }

    @ViewBuilder
    private var paginationOverlay: some View {
        let drag = DragGesture(minimumDistance: 15).onEnded { value in
            guard !isLoading else { return }
            let w = value.translation.width
            let magnitude = abs(w)
            if magnitude < 40 { return }
            let steps = min(10, Int(magnitude / 120) + 1)
            let dir = w < 0 ? 1 : -1
            let target = max(1, search.page + dir * steps)
            if originPage == nil { originPage = search.page }
            Task { await load(page: target, replace: true) }
            if let origin = originPage, abs(target - origin) >= 3 {
                withAnimation { showBackToOrigin = true }
            }
        }

        PaginationHUD(
            isLoading: isLoading,
            isFindingLast: isFindingLast,
            currentPage: search.page,
            pages: pagesWindowArray,
            goFirst: {
                guard !isLoading else { return }
                if originPage == nil { originPage = search.page }
                Task { await load(page: 1, replace: true) }
                if let origin = originPage, origin > 3 { withAnimation { showBackToOrigin = true } }
            },
            goPrev: { prevAction() },
            selectPage: { p in
                guard !isLoading else { return }
                Task { await load(page: max(1, p), replace: true) }
            },
            goNext: { nextAction() },
            goLast: {
                guard !isLoading else { return }
                if originPage == nil { originPage = search.page }
                Task {
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
        )
        .gesture(drag)
        .accessibilityLabel("Page controls")
    }

    @ViewBuilder
    private var errorOverlay: some View {
        if let msg = lastErrorMessage {
            ErrorToast(message: msg, retry: { refreshAction() })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { lastErrorMessage = nil }
                    }
                }
        }
    }

    @ViewBuilder
    private var backToOriginOverlay: some View {
        if showBackToOrigin, let origin = originPage, origin != search.page {
            BackToOriginChip(page: origin) {
                Task { await load(page: origin, replace: true) }
                withAnimation {
                    showBackToOrigin = false
                    originPage = nil
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    withAnimation { showBackToOrigin = false }
                }
            }
        }
    }

    @MainActor
    private func refresh() async {
        search.page = 1
        posts.removeAll()
        hasMore = true
        isLoadingMore = false
        nextPageInFlight = nil
        await load(page: 1, replace: true)
    }

    @MainActor
    private func load(page: Int, replace: Bool = true) async {
        if replace {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore, hasMore else { return }
            isLoadingMore = true
            nextPageInFlight = page
        }
        defer {
            if replace { isLoading = false } else { isLoadingMore = false }
            if !replace { nextPageInFlight = nil }
        }
        do {
            let next = try await dependencies.searchPosts.execute(
                query: search.danbooruQuery,
                page: page,
                limit: search.pageSize
            )
            if replace {
                posts = next
            } else {
                posts.append(contentsOf: next)
            }
            // hasMore true, если получили полный лимит; иначе достигнут конец
            hasMore = next.count == search.pageSize
            self.search.page = max(1, page)
        } catch {
            withAnimation {
                lastErrorMessage = "Failed to load posts: \(error.localizedDescription)"
            }
            if !replace {
                hasMore = false
            }
            print("Failed to load posts for page \(page): \(error)")
        }
    }

    @MainActor
    private func loadMoreIfNeeded() async {
        guard search.infiniteScrollEnabled else { return }
        guard hasMore, !isLoadingMore else { return }
        let candidate = search.page + 1
        if let inflight = nextPageInFlight, inflight >= candidate {
            return
        }
        nextPageInFlight = candidate
        #if DEBUG
            print("[InfiniteScroll] loading page=\(candidate) (current=\(search.page))")
        #endif
        await load(page: candidate, replace: false)
    }

    private func recomputeColumns() {
        columns = [
            GridItem(.adaptive(minimum: search.tileSize.minColumnWidth), spacing: gridSpacing)
        ]
    }

    // MARK: - Actions
    private func prevAction() {
        guard !search.infiniteScrollEnabled else { return }
        guard !isLoading, search.page > 1 else { return }
        Task { await load(page: max(1, search.page - 1), replace: true) }
    }

    private func nextAction() {
        guard !search.infiniteScrollEnabled else { return }
        guard !isLoading else { return }
        Task { await load(page: search.page + 1, replace: true) }
    }

    private func refreshAction() {
        Task { await refresh() }
    }

    // MARK: - Pagination window
    private var pagesWindowArray: [Int] {
        let current = search.page
        let start = max(1, current - windowRadius)
        let end = max(start, current + windowRadius)
        return Array(start...end)
    }

    // Поиск последней страницы: экспоненциальный рост и бинарный поиск
    @MainActor
    private func findLastPage() async -> Int? {
        // быстрый гвард: если текущая страница вернула меньше лимита, она и есть последняя
        if posts.count < search.pageSize { return max(1, search.page) }

        let limit = search.pageSize
        var low = max(1, search.page)
        var high = low + 1
        var requests = 0
        let maxRequests = 12

        func fetchCount(_ page: Int) async -> Int? {
            do {
                let arr = try await dependencies.searchPosts.execute(
                    query: search.danbooruQuery, page: page, limit: limit)
                return arr.count
            } catch {
                print("findLastPage fetch failed page=\(page): \(error)")
                return nil
            }
        }

        // Поиск верхней границы: постепенное расширение окна
        while requests < maxRequests {
            requests += 1
            if let cnt = await fetchCount(high) {
                if cnt == 0 {
                    break  // нашли пустую верхнюю границу
                } else if cnt < limit {
                    // high неполная — это последняя
                    return high
                } else {
                    low = high
                    high = high + 8  // аккуратно расширяем окно, чтобы не бомбить API
                }
            } else {
                break
            }
        }

        // Если верхняя граница не найдена, попробуем ещё пару шагов
        if high <= low { high = low + 8 }

        // Бинарный поиск между low..high, чтобы найти последнюю непустую страницу
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

// MARK: - Subviews

// removed AnyView type eraser to reduce type-checking complexity

private struct PostsGridScroll: View {
    let posts: [Post]
    let tileHeight: CGFloat
    let columns: [GridItem]
    let gridSpacing: CGFloat
    let isLoading: Bool
    let layout: SearchState.LayoutMode
    let infiniteEnabled: Bool
    var onReachedEnd: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            if layout == .grid {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    // Use enumerated to detect near-end items reliably
                    ForEach(Array(posts.enumerated()), id: \.1.id) { index, post in
                        NavigationLink(value: post) {
                            PostTileView(post: post, height: tileHeight)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .id(post.id)
                        .buttonStyle(.plain)
                        .frame(height: tileHeight)
                        .modifier(AnimatedItemModifier(index: index))
                        .onAppear {
                            guard infiniteEnabled else { return }
                            let threshold = max(0, posts.count - 5)
                            if index >= threshold { onReachedEnd?() }
                        }
                    }
                    if isLoading { ProgressView().padding() }
                    // Keep a sentinel as a fallback; it may help in small datasets
                    if infiniteEnabled { EndReachedSentinel().onAppear { onReachedEnd?() } }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
            } else {
                LazyVStack(alignment: .leading, spacing: gridSpacing) {
                    ForEach(Array(posts.enumerated()), id: \.1.id) { index, post in
                        NavigationLink(value: post) {
                            PostTileView(post: post, height: tileHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .id(post.id)
                        .buttonStyle(.plain)
                        .frame(height: tileHeight)
                        .padding(.horizontal, 32)
                        .modifier(AnimatedItemModifier(index: index))
                        .onAppear {
                            guard infiniteEnabled else { return }
                            let threshold = max(0, posts.count - 5)
                            if index >= threshold { onReachedEnd?() }
                        }
                    }
                    if isLoading { ProgressView().padding() }
                    if infiniteEnabled { EndReachedSentinel().onAppear { onReachedEnd?() } }
                }
                .padding(.vertical, 28)
            }
        }
    }
}

// Sentinel view to detect end-of-list appearance
private struct EndReachedSentinel: View {
    var body: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct PaginationHUD: View {
    let isLoading: Bool
    let isFindingLast: Bool
    let currentPage: Int
    let pages: [Int]
    let goFirst: () -> Void
    let goPrev: () -> Void
    let selectPage: (Int) -> Void
    let goNext: () -> Void
    let goLast: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ModernIconButton(
                systemName: "backward.end.fill",
                disabled: isLoading || currentPage == 1,
                action: goFirst
            )
            ModernIconButton(
                systemName: "chevron.left",
                disabled: isLoading || currentPage == 1,
                action: goPrev
            )

            HStack(spacing: 6) {
                ForEach(pages, id: \.self) { p in
                    ModernPageButton(
                        number: p,
                        isCurrent: p == currentPage,
                        disabled: isLoading || p < 1
                    ) {
                        selectPage(p)
                    }
                }
            }
            .padding(.horizontal, 6)

            ModernIconButton(
                systemName: "chevron.right",
                disabled: isLoading,
                action: goNext
            )
            ModernIconButton(
                systemName: "forward.end.fill",
                disabled: isLoading,
                showsProgress: isFindingLast,
                action: goLast
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.05))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

private struct ModernIconButton: View {
    let systemName: String
    var disabled: Bool = false
    var showsProgress: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    if hovering && !disabled {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.12))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.05))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(hovering && !disabled ? 0.25 : 0.1), lineWidth: 1)
            )
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .disabled(disabled || showsProgress)
        .opacity(disabled && !showsProgress ? 0.5 : 1.0)
        .scaleEffect(hovering && !disabled ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.hovering = hovering
            }
        }
    }
}

private struct ModernPageButton: View {
    let number: Int
    var isCurrent: Bool
    var disabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(size: 14, weight: isCurrent ? .bold : .semibold))
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(0.2))
                        } else if hovering && !disabled {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(0.1))
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.clear)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isCurrent ? .white.opacity(0.4) : .white.opacity(hovering ? 0.2 : 0.05),
                            lineWidth: isCurrent ? 1.5 : 1
                        )
                )
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
        .scaleEffect(hovering && !disabled ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.hovering = hovering
            }
        }
    }
}

private struct ErrorToast: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Error")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }

            Button("Retry") {
                retry()
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.red.opacity(0.05))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.red.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

private struct BackToOriginChip: View {
    let page: Int
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .semibold))
                Text("Back to p\(page)")
                    .font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.blue.opacity(hovering ? 0.15 : 0.1))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .scaleEffect(hovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.hovering = hovering
            }
        }
        .shadow(color: .blue.opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

struct ContentView: View {
    @StateObject private var search = SearchState()
    var body: some View {
        NavigationSplitView {
            SidebarView(state: search) {
                // запуск поиска
                Task { await resetAndSearch() }
            }
            .frame(minWidth: 260, maxWidth: 320)
        } detail: {
            NavigationStack {
                PostGridView(search: search)
                    .padding(.trailing, 8)
                    .navigationDestination(for: Post.self) { post in
                        PostDetailView(post: post)
                    }
            }
        }
        .environmentObject(search)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        .background(
            LinearGradient(
                colors: [
                    Color("PrimaryBackground"),
                    Color("SecondaryBackground").opacity(0.85),
                    Color("PrimaryBackground").opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    @MainActor
    private func resetAndSearch() async {
        // сброс грида и загрузка первой страницы под новый запрос
        // фактическая очистка в PostGridView происходит по refresh()
        // здесь просто увеличим page и дадим сигнал обновиться
        // (упрощённо — можно сделать через ObservableObject/Publisher позже)
        // Ничего не делаем здесь, так как PostGridView сам вызывает .task { load(page:1) }
    }
}

// MARK: - Animated Item Modifier
private struct AnimatedItemModifier: ViewModifier {
    let index: Int
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 0.3)
                        .delay(Double(index) * 0.05)
                ) {
                    hasAppeared = true
                }
            }
    }
}
