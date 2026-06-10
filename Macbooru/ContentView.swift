//
//  ContentView.swift
//  Macbooru
//

//

import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct PostGridView: View {
    @ObservedObject var search: SearchState
    @Environment(\.appDependencies) private var dependencies
    @AppStorage("settings.autoRefreshOnLaunch") private var autoRefreshOnLaunch: Bool = true
    @StateObject private var viewModel: PostGridViewModel

    @State private var columns: [GridItem] = []
    @State private var didHandleInitialLoad = false
    private let gridSpacing: CGFloat = 24

    init(search: SearchState) {
        self.search = search
        _viewModel = StateObject(wrappedValue: PostGridViewModel(search: search))
    }

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
                                return nil  
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
            posts: viewModel.posts,
            tileHeight: search.tileSize.height,
            columns: columns,
            gridSpacing: gridSpacing,
            isLoading: viewModel.isLoading || viewModel.isLoadingMore,
            infiniteEnabled: search.infiniteScrollEnabled,
            onReachedEnd: {
                guard search.infiniteScrollEnabled else { return }
                viewModel.loadMoreIfNeeded()
            }
        )
        #if os(macOS)
            .overlay(
                TrackpadSwipeMonitor(
                    onLeft: { viewModel.nextAction() },
                    onRight: { viewModel.prevAction() }
                )
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
        #endif

        .navigationTitle("Посты")
        .onAppear {
            viewModel.inject(dependencies: dependencies)
            recomputeColumns()
        }
        .task {
            guard !didHandleInitialLoad else { return }
            didHandleInitialLoad = true
            guard autoRefreshOnLaunch else { return }
            viewModel.scheduleInitialLoad()
        }
        .onChangeCompat(of: search.tileSize) { _ in
            recomputeColumns()
        }
        .onChangeCompat(of: search.searchTrigger) { _ in
            viewModel.handleSearchTriggerChange()
        }
        #if os(macOS)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > 60, abs(dy) < 40 else { return }
                        if dx < 0 {
                            viewModel.nextAction()
                        } else {
                            viewModel.prevAction()
                        }
                    }
            )
        #endif
        .focusedSceneValue(\.gridActions, gridActions)
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
        Button(action: { viewModel.refreshAction() }) {
            Label("Обновить", systemImage: "arrow.clockwise")
        }
    }

    @ViewBuilder
    private var paginationOverlay: some View {
        let drag = DragGesture(minimumDistance: 15).onEnded { value in
            guard !viewModel.isLoading else { return }
            let w = value.translation.width
            let magnitude = abs(w)
            if magnitude < 40 { return }
            let steps = min(10, Int(magnitude / 120) + 1)
            let dir = w < 0 ? 1 : -1
            viewModel.paginateByDrag(steps: steps, direction: dir)
        }

        PaginationHUD(
            isLoading: viewModel.isLoading,
            isFindingLast: viewModel.isFindingLast,
            currentPage: search.page,
            pages: viewModel.pagesWindowArray,
            goFirst: { viewModel.goFirst() },
            goPrev: { viewModel.prevAction() },
            selectPage: { viewModel.selectPage($0) },
            goNext: { viewModel.nextAction() },
            goLast: { viewModel.goLast() }
        )
        .gesture(drag)
        .accessibilityLabel("Управление страницами")
    }

    @ViewBuilder
    private var errorOverlay: some View {
        if let msg = viewModel.lastErrorMessage {
            ErrorToast(message: msg, retry: { viewModel.refreshAction() })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { viewModel.lastErrorMessage = nil }
                    }
                }
        }
    }

    @ViewBuilder
    private var backToOriginOverlay: some View {
        if viewModel.showBackToOrigin, let origin = viewModel.originPage, origin != search.page {
            BackToOriginChip(page: origin) {
                viewModel.backToOrigin()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    withAnimation { viewModel.showBackToOrigin = false }
                }
            }
        }
    }

    private func recomputeColumns() {
        columns = [
            GridItem(.adaptive(minimum: search.tileSize.minColumnWidth), spacing: gridSpacing)
        ]
    }

    private var gridActions: GridActions {
        GridActions(
            prev: { viewModel.prevAction() },
            next: { viewModel.nextAction() },
            refresh: { viewModel.refreshAction() }
        )
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
    let infiniteEnabled: Bool
    var onReachedEnd: (() -> Void)? = nil

    var body: some View {
        let nearEndStartIndex = max(0, posts.count - 5)
        ScrollView {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(posts) { post in
                    let index = posts.firstIndex(where: { $0.id == post.id }) ?? 0
                    NavigationLink(value: post) {
                        PostTileView(post: post, height: tileHeight)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(height: tileHeight)
                    .modifier(AnimatedItemModifier(index: index))
                    .onAppear {
                        guard infiniteEnabled else { return }
                        if index >= nearEndStartIndex { onReachedEnd?() }
                    }
                }
                if isLoading { ProgressView().padding() }
                // Keep a sentinel as a fallback; it may help in small datasets
                if infiniteEnabled { EndReachedSentinel().onAppear { onReachedEnd?() } }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
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
            Theme.IconButton(
                systemName: "backward.end.fill",
                isDisabled: isLoading || currentPage == 1,
                action: goFirst
            )
            Theme.IconButton(
                systemName: "chevron.left",
                isDisabled: isLoading || currentPage == 1,
                action: goPrev
            )

            HStack(spacing: 6) {
                ForEach(pages, id: \.self) { p in
                    Theme.PageButton(
                        number: p,
                        isCurrent: p == currentPage,
                        isDisabled: isLoading || p < 1
                    ) {
                        selectPage(p)
                    }
                }
            }
            .padding(.horizontal, 6)

            Theme.IconButton(
                systemName: "chevron.right",
                isDisabled: isLoading,
                action: goNext
            )
            Theme.IconButton(
                systemName: "forward.end.fill",
                isDisabled: isLoading,
                showsProgress: isFindingLast,
                action: goLast
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 20, hoverElevates: false)
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
                Text("Ошибка")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }

            Button("Повторить") {
                retry()
            }
            .buttonStyle(.bordered)
            .modifier(CapsuleBorderShapeIfAvailable())
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
    @Environment(\.lowPerformance) private var lowPerf

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .semibold))
                Text("Вернуться к стр. \(page)")
                    .font(.footnote.weight(.medium))
            }
            .themedChip(tint: Theme.ColorPalette.accent, style: .standard, size: .large)
            .foregroundStyle(Theme.ColorPalette.accent)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        Theme.ColorPalette.accent.opacity(hovering ? 0.45 : 0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(lowPerf ? 1.0 : (hovering ? 1.03 : 1.0))
        .shadow(
            color: Theme.ColorPalette.accent.opacity(hovering ? 0.25 : 0.18),
            radius: hovering ? 10 : 6,
            x: 0,
            y: hovering ? 4 : 2
        )
        .animation(lowPerf ? nil : Theme.Animations.interactive(lowPerformance: lowPerf), value: hovering)
        .onHover { value in
            if lowPerf {
                hovering = value
            } else {
                withAnimation(Theme.Animations.hover(lowPerformance: lowPerf)) {
                    hovering = value
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var search: SearchState
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        NavigationSplitView {
            SidebarView(state: search)
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
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        .background(Theme.Gradients.appBackground(for: colorScheme).ignoresSafeArea())
    }
}

// MARK: - Animated Item Modifier
private struct AnimatedItemModifier: ViewModifier {
    let index: Int
    @Environment(\.lowPerformance) private var lowPerf
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .onAppear {
                guard !hasAppeared else { return }
                let anim: Animation = {
                    if lowPerf || index > 10 {
                        return .linear(duration: 0)
                    }
                    return Theme.Animations.stagger(
                        index: index, baseDelay: 0.015, style: .quick, lowPerformance: lowPerf
                    )
                }()
                withAnimation(anim) {
                    hasAppeared = true
                }
            }
    }
}

private struct CapsuleBorderShapeIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.buttonBorderShape(.capsule)
        } else {
            content
        }
    }
}
