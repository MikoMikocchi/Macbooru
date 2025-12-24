import SwiftUI

// Types Post и RemoteImage должны быть в том же таргете. Импорт доп. модулей не требуется.

#if os(macOS)
    import AppKit
    import ObjectiveC
#endif

struct PostDetailView: View {
    let post: Post
    @EnvironmentObject private var search: SearchState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @EnvironmentObject private var dependenciesStore: AppDependenciesStore
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel: PostDetailViewModel

    // Зум и панорамирование (UI state)
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    
    // One-time sync
    @State private var didSyncInitialState = false

    private let imageCornerRadius: CGFloat = 24

    init(post: Post) {
        self.post = post
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(post: post))
    }

    @ViewBuilder
    private func openMenu(state: ActionChip.ChipState = .normal) -> some View {
        Menu {
            Button("Open post page", systemImage: "link") {
                #if os(macOS)
                    NSWorkspace.shared.open(viewModel.pageURL)
                #endif
            }
            if let u = post.largeURL {
                Button("Open large", systemImage: "safari") {
                    #if os(macOS)
                        NSWorkspace.shared.open(u)
                    #endif
                }
            }
            if let u = post.fileURL {
                Button("Open original", systemImage: "safari") {
                    #if os(macOS)
                        NSWorkspace.shared.open(u)
                    #endif
                }
            }
            if let src = post.source, let u = URL(string: src) {
                Button("Open source", systemImage: "safari") {
                    #if os(macOS)
                        NSWorkspace.shared.open(u)
                    #endif
                }
            }
        } label: {
            ActionChip(
                title: "Open",
                systemImage: "safari",
                tint: .cyan,
                state: state,
                accessibilityHint: "Open the post links in browser"
            )
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func copyMenu(state: ActionChip.ChipState = .normal) -> some View {
        Menu {
            Button("Copy post URL", systemImage: "link") { copyPostURL() }
            if post.fileURL != nil || post.largeURL != nil {
                Button("Copy image", systemImage: "photo.on.rectangle") {
                    Task { await viewModel.copyImageToPasteboard() }
                }
            }
            if post.fileURL != nil {
                Button("Copy original URL", systemImage: "link.badge.plus") {
                    copyOriginalURL()
                }
            }
            if let src = post.source, URL(string: src) != nil {
                Button("Copy source URL", systemImage: "doc.on.doc") {
                    copySourceURL()
                }
            }
            Divider()
            Button("Copy tags", systemImage: "doc.on.doc") {
                copyTagsToPasteboard()
            }
        } label: {
            ActionChip(
                title: "Copy",
                systemImage: "doc.on.doc",
                tint: .mint,
                state: state,
                accessibilityHint: "Copy useful links for the post"
            )
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func interactMenu(state: ActionChip.ChipState) -> some View {
        Menu {
            Button {
                Task { await viewModel.performFavorite(add: !viewModel.currentFavoriteState) }
            } label: {
                Label(
                    viewModel.currentFavoriteState ? "Убрать из избранного" : "В избранное",
                    systemImage: viewModel.currentFavoriteState ? "heart.slash" : "heart"
                )
            }
            .disabled(viewModel.isInteractionInProgress || !dependenciesStore.hasCredentials)

            Divider()

            Button {
                Task { await viewModel.performVote(score: 1) }
            } label: {
                Label("Vote +1", systemImage: "hand.thumbsup")
            }
            .disabled(
                viewModel.isInteractionInProgress
                    || !dependenciesStore.hasCredentials
                    || viewModel.lastVoteScore == 1
            )

            Button {
                Task { await viewModel.performVote(score: -1) }
            } label: {
                Label("Vote -1", systemImage: "hand.thumbsdown")
            }
            .disabled(
                viewModel.isInteractionInProgress
                    || !dependenciesStore.hasCredentials
                    || viewModel.lastVoteScore == -1
            )
        } label: {
            ActionChip(
                title: "Interact",
                systemImage: "hand.tap",
                tint: .pink,
                state: state,
                accessibilityHint: "Favorite or vote on the post"
            )
        }
        .menuStyle(.borderlessButton)
        .disabled(!dependenciesStore.hasCredentials || state == .loading)
        .help(
            dependenciesStore.hasCredentials
                ? "Избранное и голосование"
                : "Укажите учетные данные Danbooru в настройках"
        )
    }

    @ViewBuilder
    private func moreMenu(state: ActionChip.ChipState = .normal) -> some View {
        Menu {
            Button("Reveal Downloads Folder", systemImage: "folder") {
                revealDownloadsFolder()
            }
        } label: {
            ActionChip(
                title: "More",
                systemImage: "ellipsis.circle",
                tint: Theme.ColorPalette.textMuted,
                state: state,
                accessibilityHint: "Reveal the Macbooru downloads folder"
            )
        }
        .menuStyle(.borderlessButton)
    }

    private var interactChipState: ActionChip.ChipState {
        if !dependenciesStore.hasCredentials { return .disabled }
        if viewModel.isInteractionInProgress { return .loading }
        return .normal
    }

    @ViewBuilder
    private func imageSection(isCompact: Bool, maxHeight: CGFloat) -> some View {
        let stackSpacing: CGFloat = isCompact ? 16 : 20
        let cardPadding: CGFloat = isCompact ? 14 : 18

        VStack(alignment: .leading, spacing: stackSpacing) {
            ZStack(alignment: .topTrailing) {
                GeometryReader { proxy in
                    // Высота зоны просмотра арта ограничена, чтобы всё умещалось на одном экране
                    let h = max(420.0, min(proxy.size.height, maxHeight))
                    let aspect: CGFloat? = {
                        if let w = post.width, let h = post.height, w > 0, h > 0 {
                            return CGFloat(w) / CGFloat(h)
                        }
                        return nil
                    }()
                    
                    ZoomableImageView(
                        zoom: $zoom,
                        lastZoom: $lastZoom,
                        offset: $offset,
                        lastDrag: $lastDrag,
                        contentBaseHeight: h,
                        containerSize: proxy.size,
                        imageAspectRatio: aspect,
                        buildContextMenu: { makeArtContextMenu() }
                    ) {
                        RemoteImage(
                            candidates: viewModel.bestImageCandidates,
                            height: h,
                            contentMode: ContentMode.fit,
                            animateFirstAppearance: true,
                            animateUpgrades: true,
                            decoratedBackground: false,
                            cornerRadius: 0
                        )
                    }
                }
                .frame(height: max(460, maxHeight))

                HStack(spacing: 12) {
                    // Fit to screen
                    Theme.IconButton(
                        systemName: "arrow.down.right.and.arrow.up.left",
                        size: Theme.Constants.controlSize + 6,
                        tint: .white,
                        showsBackground: true,
                        showsStroke: true,
                        usesMaterial: false,
                        action: resetZoom
                    )
                    .help("Сбросить зум и позицию")

                    // Zoom out / in with disabled states at bounds
                    Theme.IconButton(
                        systemName: "minus.magnifyingglass",
                        size: Theme.Constants.controlSize + 6,
                        isDisabled: zoom <= 0.51,
                        tint: .white,
                        showsBackground: true,
                        showsStroke: true,
                        usesMaterial: false,
                        action: { stepZoom(in: -1) }
                    )

                    Theme.IconButton(
                        systemName: "plus.magnifyingglass",
                        size: Theme.Constants.controlSize + 6,
                        isDisabled: zoom >= 5.99,
                        tint: .white,
                        showsBackground: true,
                        showsStroke: true,
                        usesMaterial: false,
                        action: { stepZoom(in: +1) }
                    )
                }
                .padding(10)
                // Материал и подложка теперь строго внутри закруглённой формы —
                // устраняем «квадратную» подложку позади панели
                .background(
                    Theme.ColorPalette.controlBackground,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.ColorPalette.glassBorder, lineWidth: 1)
                )
                .padding(10)
            }
            .padding(cardPadding)
            .glassCard(cornerRadius: imageCornerRadius, hoverElevates: false)

            ActionsCard(
                openMenu: { openMenu() },
                copyMenu: { copyMenu() },
                interactMenu: { interactMenu(state: interactChipState) },
                moreMenu: { moreMenu() },
                onDownload: { Task { await viewModel.downloadBestImage() } },
                downloadDisabled: viewModel.bestImageCandidates.isEmpty,
                isDownloading: viewModel.isDownloading
            )
        }
    }

    @ViewBuilder
    private func infoSection(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            InfoCard(
                post: post,
                favoriteCount: viewModel.favoriteCount ?? post.favCount,
                isFavorited: viewModel.isFavorited,
                upScore: viewModel.upScore ?? post.upScore,
                downScore: viewModel.downScore ?? post.downScore
            )

            TagsCard(
                post: post,
                onOpenTag: { tag in openSearchInApp(tag) },
                onCopyTag: { tag in copySingleTag(tag) }
            )

            CommentsCard(
                comments: viewModel.comments,
                isLoading: viewModel.isLoadingComments,
                error: viewModel.commentsError,
                hasMore: viewModel.hasMoreComments,
                isLoadingMore: viewModel.isLoadingMoreComments,
                newComment: $viewModel.newComment,
                isSubmitting: viewModel.isSubmittingComment,
                canSubmit: dependenciesStore.hasCredentials,
                onReload: { Task { await viewModel.refreshComments() } },
                onLoadMore: { Task { await viewModel.loadMoreComments() } },
                onSubmit: { Task { await viewModel.submitComment() } }
            )
        }
        .padding(.vertical, isCompact ? 0 : 4)
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 900
            // Ещё немного уменьшаем резерв, чтобы подтянуть интерфейс к нижней границе окна
            let reserved: CGFloat = isCompact ? 160 : 180
            let imageMaxHeight = max(420, proxy.size.height - reserved)
            ScrollView(showsIndicators: false) {
                Group {
                    if isCompact {
                        VStack(alignment: .leading, spacing: 24) {
                            imageSection(isCompact: true, maxHeight: imageMaxHeight)
                            infoSection(isCompact: true)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 24) {
                            imageSection(isCompact: false, maxHeight: imageMaxHeight)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            infoSection(isCompact: false)
                                .frame(maxWidth: 360, alignment: .topLeading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(
                isCompact
                    ? EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16)
                    : EdgeInsets(top: 24, leading: 24, bottom: 4, trailing: 24)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.Gradients.appBackground(for: colorScheme).ignoresSafeArea())
        }
        .navigationTitle("Post #\(post.id)")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { copyTagsToPasteboard() }) { Image(systemName: "doc.on.doc") }
                    .help("Copy tags")
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button(action: { Task { await viewModel.downloadBestImage() } }) {
                    if viewModel.isDownloading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "tray.and.arrow.down")
                    }
                }
                .disabled(viewModel.isDownloading || viewModel.bestImageCandidates.isEmpty)
                .help("Download best image")
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = viewModel.saveMessage {
                Text(msg)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }
        }
        .task(id: post.id) {
            viewModel.inject(dependencies: dependencies)
            viewModel.hasCredentials = dependenciesStore.hasCredentials
            viewModel.onAuthenticationFailure = { [weak dependenciesStore] msg in
                dependenciesStore?.handleAuthenticationFailure(message: msg)
            }
            await viewModel.refreshComments()
        }
        .onAppear {
            if !didSyncInitialState {
                viewModel.syncPostState()
                didSyncInitialState = true
            }
            viewModel.hasCredentials = dependenciesStore.hasCredentials
        }
        .onChange(of: dependenciesStore.credentials) { _ in
            viewModel.hasCredentials = dependenciesStore.hasCredentials
        }
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.15)) {
            zoom = 1.0
            lastZoom = 1.0
            offset = .zero
            lastDrag = .zero
        }
    }

    private func stepZoom(in direction: Int) {
        let step: CGFloat = 0.2
        var new = zoom + step * CGFloat(direction)
        new = min(6.0, max(0.5, new))
        lastZoom = new
        withAnimation(.easeInOut(duration: 0.12)) { zoom = new }
    }


    private func copyTagsToPasteboard() {
        #if os(macOS)
            if let s = post.tagString, !s.isEmpty {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(s, forType: .string)
                viewModel.showToast("Tags copied")
            }
        #endif
    }

    // ЛКМ: начать поиск по тегу внутри приложения и закрыть детальный экран
    private func openSearchInApp(_ tag: String) {
        // Заменяем текущий запрос ровно на один выбранный тег
        let token = tag.replacingOccurrences(of: " ", with: "_")
        search.tags = token
        search.resetForNewSearch()
        dismiss()
    }

    // ПКМ: скопировать конкретный тег и показать явный тост
    private func copySingleTag(_ tag: String) {
        #if os(macOS)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(tag, forType: .string)
            viewModel.showToast("Tag copied: \(tag)")
        #endif
    }

    private func copyOriginalURL() {
        #if os(macOS)
            guard let url = post.fileURL else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(url.absoluteString, forType: .string)
            viewModel.showToast("Original URL copied")
        #endif
    }

    private func copyPostURL() {
        #if os(macOS)
            let url = viewModel.pageURL
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(url.absoluteString, forType: .string)
            viewModel.showToast("Post URL copied")
        #endif
    }

    private func copySourceURL() {
        #if os(macOS)
            guard let src = post.source, let url = URL(string: src) else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(url.absoluteString, forType: .string)
            viewModel.showToast("Source URL copied")
        #endif
    }

    private func revealDownloadsFolder() {
        #if os(macOS)
            do {
                let downloads = try FileManager.default.url(
                    for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil,
                    create: false)
                NSWorkspace.shared.activateFileViewerSelecting([downloads])
            } catch {
                viewModel.showToast("Cannot open Downloads: \(error.localizedDescription)")
            }
        #endif
    }

    // MARK: - Контекстное меню по арту (macOS)
    #if os(macOS)
        private func makeArtContextMenu() -> NSMenu {
            let menu = NSMenu()

            // Зум
            menu.addItem(
                withTitle: "Fit", action: #selector(MenuActionTarget.fit), keyEquivalent: "f")
            menu.addItem(
                withTitle: "Zoom In", action: #selector(MenuActionTarget.zoomIn), keyEquivalent: "+"
            )
            menu.addItem(
                withTitle: "Zoom Out", action: #selector(MenuActionTarget.zoomOut),
                keyEquivalent: "-")
            menu.addItem(NSMenuItem.separator())

            // Позиционирование
            menu.addItem(
                withTitle: "Center", action: #selector(MenuActionTarget.center), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())

            // Открыть
            let openPost = NSMenuItem(
                title: "Open Post Page", action: #selector(MenuActionTarget.openPostPage),
                keyEquivalent: "")
            menu.addItem(openPost)
            if post.largeURL != nil {
                menu.addItem(
                    NSMenuItem(
                        title: "Open Large", action: #selector(MenuActionTarget.openLarge),
                        keyEquivalent: ""))
            }
            if post.fileURL != nil {
                menu.addItem(
                    NSMenuItem(
                        title: "Open Original", action: #selector(MenuActionTarget.openOriginal),
                        keyEquivalent: ""))
            }
            menu.addItem(NSMenuItem.separator())

            // Буфер/загрузка
            menu.addItem(
                NSMenuItem(
                    title: "Copy Tags", action: #selector(MenuActionTarget.copyTags),
                    keyEquivalent: ""))
            menu.addItem(
                NSMenuItem(
                    title: "Copy Post URL",
                    action: #selector(MenuActionTarget.copyPostURL),
                    keyEquivalent: ""))
            if post.fileURL != nil {
                menu.addItem(
                    NSMenuItem(
                        title: "Copy Original URL",
                        action: #selector(MenuActionTarget.copyOriginalURL),
                        keyEquivalent: ""))
            }
            if post.fileURL != nil || post.largeURL != nil || post.previewURL != nil {
                menu.addItem(
                    NSMenuItem(
                        title: "Copy Image",
                        action: #selector(MenuActionTarget.copyImage),
                        keyEquivalent: ""))
            }
            if let src = post.source, URL(string: src) != nil {
                menu.addItem(
                    NSMenuItem(
                        title: "Copy Source URL",
                        action: #selector(MenuActionTarget.copySourceURL),
                        keyEquivalent: ""))
            }
            menu.addItem(
                NSMenuItem(
                    title: "Download Best Image", action: #selector(MenuActionTarget.download),
                    keyEquivalent: ""))
            menu.addItem(
                NSMenuItem(
                    title: "Reveal Downloads Folder",
                    action: #selector(MenuActionTarget.revealDownloadsFolder),
                    keyEquivalent: ""))

            // Таргет для действий
            let target = MenuActionTarget(
                fitAction: { resetZoom() },
                zoomInAction: { stepZoom(in: +1) },
                zoomOutAction: { stepZoom(in: -1) },
                centerAction: { withAnimation(.easeInOut(duration: 0.15)) { offset = .zero } },
                openPostPageAction: { NSWorkspace.shared.open(viewModel.pageURL) },
                openLargeAction: { if let u = post.largeURL { NSWorkspace.shared.open(u) } },
                openOriginalAction: { if let u = post.fileURL { NSWorkspace.shared.open(u) } },
                copyTagsAction: { copyTagsToPasteboard() },
                copyPostURLAction: { copyPostURL() },
                copyOriginalURLAction: { copyOriginalURL() },
                copyImageAction: { Task { await viewModel.copyImageToPasteboard() } },
                copySourceURLAction: { copySourceURL() },
                downloadAction: { Task { await viewModel.downloadBestImage() } },
                revealDownloadsFolderAction: { revealDownloadsFolder() }
            )
            // Назначаем целевой объект меню и действию
            for item in menu.items where item.action != nil {
                item.target = target
            }
            // Удерживаем target живым до закрытия меню
            objc_setAssociatedObject(
                menu, &MenuActionTarget.associatedKey, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            return menu
        }

    #endif
}
