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

    // Зум и панорамирование
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var saveMessage: String? = nil
    @State private var comments: [Comment] = []
    @State private var isLoadingComments = false
    @State private var commentsError: String? = nil
    @State private var newComment: String = ""
    @State private var isSubmittingComment = false
    @State private var isInteractionInProgress = false
    @State private var isFavorited: Bool? = nil
    @State private var favoriteCount: Int? = nil
    @State private var upScore: Int? = nil
    @State private var downScore: Int? = nil
    @State private var lastVoteScore: Int? = nil
    @State private var didSyncInitialState = false
    @State private var commentsPage: Int = 1
    @State private var hasMoreComments: Bool = true
    @State private var isLoadingMoreComments: Bool = false
    @State private var isDownloading = false

    private let commentsPageSize = 40

    private let imageCornerRadius: CGFloat = 24

    private var bestImageCandidates: [URL] {
        [post.largeURL, post.fileURL, post.previewURL].compactMap { $0 }
    }
    private var pageURL: URL { URL(string: "https://danbooru.donmai.us/posts/\(post.id)")! }

    @ViewBuilder
    private func openMenu(state: ActionChip.ChipState = .normal) -> some View {
        Menu {
            Button("Open post page", systemImage: "link") {
                #if os(macOS)
                    NSWorkspace.shared.open(pageURL)
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
                    Task { await copyImageToPasteboard() }
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
                Task { await performFavorite(add: !currentFavoriteState) }
            } label: {
                Label(
                    currentFavoriteState ? "Убрать из избранного" : "В избранное",
                    systemImage: currentFavoriteState ? "heart.slash" : "heart"
                )
            }
            .disabled(isInteractionInProgress || !dependenciesStore.hasCredentials)

            Divider()

            Button {
                Task { await performVote(score: 1) }
            } label: {
                Label("Vote +1", systemImage: "hand.thumbsup")
            }
            .disabled(
                isInteractionInProgress
                    || !dependenciesStore.hasCredentials
                    || lastVoteScore == 1
            )

            Button {
                Task { await performVote(score: -1) }
            } label: {
                Label("Vote -1", systemImage: "hand.thumbsdown")
            }
            .disabled(
                isInteractionInProgress
                    || !dependenciesStore.hasCredentials
                    || lastVoteScore == -1
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
        if isInteractionInProgress { return .loading }
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
                    RemoteImage(
                        candidates: bestImageCandidates,
                        height: h,
                        contentMode: ContentMode.fit,
                        animateFirstAppearance: true,
                        animateUpgrades: true,
                        decoratedBackground: false,
                        cornerRadius: 0
                    )
                    .scaleEffect(zoom)
                    .offset(offset)
                    .onChange(of: zoom) { _, _ in
                        offset = clampedOffset(
                            offset,
                            containerSize: proxy.size,
                            contentBaseHeight: h
                        )
                    }
                    #if os(macOS)
                        .overlay(
                            PanZoomProxy(
                                onPan: { delta in
                                    let candidate = CGSize(
                                        width: offset.width + delta.width,
                                        height: offset.height + delta.height
                                    )
                                    offset = softClampedOffset(
                                        candidate,
                                        containerSize: proxy.size,
                                        contentBaseHeight: h
                                    )
                                    lastDrag = offset
                                },
                                onPanEnd: {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        offset = hardClampedOffset(
                                            offset,
                                            containerSize: proxy.size,
                                            contentBaseHeight: h
                                        )
                                    }
                                    lastDrag = offset
                                },
                                onMagnify: { scale, location in
                                    let old = zoom
                                    let next = min(6.0, max(0.5, old * scale))
                                    if old != 0, next != old {
                                        let factor = next / old
                                        let center = CGPoint(
                                            x: proxy.size.width / 2,
                                            y: proxy.size.height / 2
                                        )
                                        let dx = (location.x - center.x) * (factor - 1)
                                        let dy = (location.y - center.y) * (factor - 1)
                                        offset = CGSize(
                                            width: offset.width - dx,
                                            height: offset.height - dy
                                        )
                                    }
                                    zoom = next
                                    lastZoom = next
                                    offset = hardClampedOffset(
                                        offset,
                                        containerSize: proxy.size,
                                        contentBaseHeight: h
                                    )
                                },
                                onDoubleClick: { _ in
                                    resetZoom()
                                },
                                buildContextMenu: { makeArtContextMenu() }
                            )
                        )
                    #else
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    zoom = min(6.0, max(0.5, lastZoom * value))
                                }
                                .onEnded { _ in
                                    lastZoom = zoom
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { g in
                                    let candidate = CGSize(
                                        width: lastDrag.width + g.translation.width,
                                        height: lastDrag.height + g.translation.height
                                    )
                                    offset = softClampedOffset(
                                        candidate,
                                        containerSize: proxy.size,
                                        contentBaseHeight: h
                                    )
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        offset = hardClampedOffset(
                                            offset,
                                            containerSize: proxy.size,
                                            contentBaseHeight: h
                                        )
                                    }
                                    lastDrag = offset
                                }
                        )
                    #endif
                    .animation(.easeInOut(duration: 0.15), value: zoom)
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
                onDownload: { Task { await downloadBestImage() } },
                downloadDisabled: bestImageCandidates.isEmpty,
                isDownloading: isDownloading
            )
        }
    }

    @ViewBuilder
    private func infoSection(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            InfoCard(
                post: post,
                favoriteCount: favoriteCount ?? post.favCount,
                isFavorited: isFavorited,
                upScore: upScore ?? post.upScore,
                downScore: downScore ?? post.downScore
            )

            TagsCard(
                post: post,
                onOpenTag: { tag in openSearchInApp(tag) },
                onCopyTag: { tag in copySingleTag(tag) }
            )

            CommentsCard(
                comments: comments,
                isLoading: isLoadingComments,
                error: commentsError,
                hasMore: hasMoreComments,
                isLoadingMore: isLoadingMoreComments,
                newComment: $newComment,
                isSubmitting: isSubmittingComment,
                canSubmit: dependenciesStore.hasCredentials,
                onReload: { Task { await refreshComments() } },
                onLoadMore: { Task { await loadMoreComments() } },
                onSubmit: { Task { await submitComment() } }
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
                Button(action: { Task { await downloadBestImage() } }) {
                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "tray.and.arrow.down")
                    }
                }
                .disabled(isDownloading || bestImageCandidates.isEmpty)
                .help("Download best image")
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = saveMessage {
                Text(msg)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { saveMessage = nil }
                        }
                    }
            }
        }
        .task(id: post.id) {
            await refreshComments()
        }
        .onAppear {
            if !didSyncInitialState {
                syncPostState()
                didSyncInitialState = true
            }
        }
    }

    @MainActor
    private func refreshComments() async {
        guard !isLoadingComments else { return }
        commentsPage = 1
        hasMoreComments = true
        comments.removeAll()
        await loadComments(page: 1, replace: true)
    }

    @MainActor
    private func submitComment() async {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSubmittingComment else { return }
        isSubmittingComment = true
        commentsError = nil
        do {
            let comment = try await dependencies.comments.create(postID: post.id, body: trimmed)
            newComment = ""
            comments.append(comment)
            comments.sort(by: commentOrder)
            saveMessage = "Comment posted"
        } catch {
            commentsError = commentErrorMessage(for: error)
        }
        isSubmittingComment = false
    }

    @MainActor
    private func loadMoreComments() async {
        guard hasMoreComments, !isLoadingMoreComments else { return }
        let nextPage = commentsPage + 1
        await loadComments(page: nextPage, replace: false)
    }

    @MainActor
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

    private func commentOrder(_ lhs: Comment, _ rhs: Comment) -> Bool {
        let lhsDate = lhs.createdAt ?? .distantPast
        let rhsDate = rhs.createdAt ?? .distantPast
        return lhsDate < rhsDate
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

    @MainActor
    private func performFavorite(add: Bool) async {
        guard dependenciesStore.hasCredentials else {
            withAnimation { saveMessage = "Добавьте учетные данные Danbooru в Настройках" }
            return
        }
        guard !isInteractionInProgress else { return }
        isInteractionInProgress = true
        defer { isInteractionInProgress = false }
        do {
            if add {
                try await dependencies.favoritePost.favorite(postID: post.id)
                updateFavoriteState(isFavorited: true)
                withAnimation { saveMessage = "Добавлено в избранное" }
            } else {
                try await dependencies.favoritePost.unfavorite(postID: post.id)
                updateFavoriteState(isFavorited: false)
                withAnimation { saveMessage = "Удалено из избранного" }
            }
        } catch {
            handleAuthErrorIfNeeded(error)
            withAnimation { saveMessage = commentErrorMessage(for: error) }
        }
    }

    @MainActor
    private func performVote(score: Int) async {
        guard dependenciesStore.hasCredentials else {
            withAnimation { saveMessage = "Добавьте учетные данные Danbooru в Настройках" }
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
            withAnimation { saveMessage = message }
        } catch {
            handleAuthErrorIfNeeded(error)
            withAnimation { saveMessage = commentErrorMessage(for: error) }
        }
    }

    private func syncPostState() {
        isFavorited = post.isFavorited
        favoriteCount = post.favCount
        upScore = post.upScore
        downScore = post.downScore
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

    private var currentFavoriteState: Bool {
        isFavorited ?? post.isFavorited ?? false
    }

    private func handleAuthErrorIfNeeded(_ error: Error) {
        if case APIError.serverError(let code) = error, code == 401 || code == 403 {
            dependenciesStore.handleAuthenticationFailure(
                message: "Недействительные учетные данные Danbooru"
            )
        }
        if let apiError = error as? APIError, case .missingCredentials = apiError {
            dependenciesStore.handleAuthenticationFailure(
                message: "Укажите учетные данные Danbooru"
            )
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

    // Ограничение смещения так, чтобы изображение не «улетало» за рамки видимой области.
    // containerSize — размер GeometryReader, contentBaseHeight — базовая высота изображения (h),
    // фактический размер содержимого зависит от зума.
    private func clampedOffset(
        _ candidate: CGSize, containerSize: CGSize, contentBaseHeight: CGFloat
    ) -> CGSize {
        // Корректно учитываем .fit: сначала вычисляем базовые размеры при fit (до зума), затем домножаем на zoom
        var contentWidth: CGFloat
        var contentHeight: CGFloat

        if let w = post.width, let h = post.height, w > 0, h > 0 {
            let aspect = CGFloat(w) / CGFloat(h)
            // Базовая (fit) ширина/высота до применения зума
            let baseWidthFit = min(containerSize.width, contentBaseHeight * aspect)
            let baseHeightFit = min(contentBaseHeight, containerSize.width / aspect)
            contentWidth = baseWidthFit * zoom
            contentHeight = baseHeightFit * zoom
        } else {
            // Без знания аспекта: считаем, что fit укладывает в заданную высоту и ширину контейнера
            contentWidth = containerSize.width * zoom
            contentHeight = contentBaseHeight * zoom
        }

        // Ограничения по половине «выпирания»
        let allowX: CGFloat = max(0, (contentWidth - containerSize.width) / 2)
        let allowY: CGFloat = max(0, (contentHeight - containerSize.height) / 2)

        // Кламп по рамке
        let clampedX = min(max(candidate.width, -allowX), allowX)
        let clampedY = min(max(candidate.height, -allowY), allowY)
        return CGSize(width: clampedX, height: clampedY)
    }

    // Мягкий кламп (фрикция у краёв) — чем дальше за пределы, тем сильнее сжатие
    private func softClampedOffset(
        _ candidate: CGSize, containerSize: CGSize, contentBaseHeight: CGFloat
    ) -> CGSize {
        // если кандидат внутри — оставляем как есть; если вышли — сжимаем превышение коэффициентом, оставляя небольшой оверсролл
        let allow = allowedHalfOverflow(
            containerSize: containerSize, contentBaseHeight: contentBaseHeight)
        let k: CGFloat = 0.35  // коэффициент «фрикции»
        let overX = overflow(candidate.width, allow: allow.x)
        let overY = overflow(candidate.height, allow: allow.y)
        let softX = candidate.width - sign(candidate.width) * max(0, abs(overX)) * (1 - k)
        let softY = candidate.height - sign(candidate.height) * max(0, abs(overY)) * (1 - k)
        // НЕ делаем жёсткий кламп во время жеста — хотим небольшой оверсролл для «пружинки»
        return CGSize(width: softX, height: softY)
    }

    private func hardClampedOffset(
        _ candidate: CGSize, containerSize: CGSize, contentBaseHeight: CGFloat
    ) -> CGSize {
        clampedOffset(candidate, containerSize: containerSize, contentBaseHeight: contentBaseHeight)
    }

    private func allowedHalfOverflow(containerSize: CGSize, contentBaseHeight: CGFloat) -> (
        x: CGFloat, y: CGFloat
    ) {
        // пересчитываем текущие contentWidth/Height по той же логике, что и в clampedOffset
        var contentWidth: CGFloat
        var contentHeight: CGFloat
        if let w = post.width, let h = post.height, w > 0, h > 0 {
            let aspect = CGFloat(w) / CGFloat(h)
            let baseWidthFit = min(containerSize.width, contentBaseHeight * aspect)
            let baseHeightFit = min(contentBaseHeight, containerSize.width / aspect)
            contentWidth = baseWidthFit * zoom
            contentHeight = baseHeightFit * zoom
        } else {
            contentWidth = containerSize.width * zoom
            contentHeight = contentBaseHeight * zoom
        }
        let allowX = max(0, (contentWidth - containerSize.width) / 2)
        let allowY = max(0, (contentHeight - containerSize.height) / 2)
        return (allowX, allowY)
    }

    private func overflow(_ value: CGFloat, allow: CGFloat) -> CGFloat {
        if value > allow { return value - allow }
        if value < -allow { return value + allow }
        return 0
    }

    private func sign(_ value: CGFloat) -> CGFloat { value >= 0 ? 1 : -1 }

    private func copyTagsToPasteboard() {
        #if os(macOS)
            if let s = post.tagString, !s.isEmpty {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(s, forType: .string)
                withAnimation { saveMessage = "Tags copied" }
            }
        #endif
    }

    @MainActor
    private func downloadBestImage() async {
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
            withAnimation { saveMessage = "Saved to Downloads/Macbooru" }
        } catch {
            withAnimation { saveMessage = "Save failed: \(error.localizedDescription)" }
        }
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
            withAnimation { saveMessage = "Tag copied: \(tag)" }
        #endif
    }

    private func copyOriginalURL() {
        #if os(macOS)
            guard let url = post.fileURL else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(url.absoluteString, forType: .string)
            withAnimation { saveMessage = "Original URL copied" }
        #endif
    }

    private func copyPostURL() {
        #if os(macOS)
            let url = pageURL
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(url.absoluteString, forType: .string)
            withAnimation { saveMessage = "Post URL copied" }
        #endif
    }

    @MainActor
    private func copyImageToPasteboard() async {
        #if os(macOS)
            guard let url = post.fileURL ?? post.largeURL ?? post.previewURL else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = NSImage(data: data) else {
                    withAnimation { saveMessage = "Cannot decode image" }
                    return
                }
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([image])
                withAnimation { saveMessage = "Image copied" }
            } catch {
                withAnimation { saveMessage = "Copy failed: \(error.localizedDescription)" }
            }
        #endif
    }

    private func copySourceURL() {
        #if os(macOS)
            guard let src = post.source, let url = URL(string: src) else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(url.absoluteString, forType: .string)
            withAnimation { saveMessage = "Source URL copied" }
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
                withAnimation {
                    saveMessage = "Cannot open Downloads: \(error.localizedDescription)"
                }
            }
        #endif
    }

    // MARK: - Контекстное меню по арту (macOS)
    #if os(macOS)
        private struct PanZoomProxy: NSViewRepresentable {
            typealias NSViewType = PanZoomNSView
            var onPan: (CGSize) -> Void
            var onPanEnd: (() -> Void)? = nil
            var onMagnify: (CGFloat, CGPoint) -> Void
            var onDoubleClick: ((CGPoint) -> Void)? = nil
            var buildContextMenu: (() -> NSMenu)? = nil

            func makeNSView(context: Context) -> PanZoomNSView {
                let view = PanZoomNSView()
                view.onPan = onPan
                view.onPanEnd = onPanEnd
                view.onMagnify = onMagnify
                view.onDoubleClick = onDoubleClick
                view.buildContextMenu = buildContextMenu
                view.wantsLayer = true
                view.layer?.backgroundColor = NSColor.clear.cgColor
                return view
            }

            func updateNSView(_ nsView: PanZoomNSView, context: Context) {
                nsView.onPan = onPan
                nsView.onPanEnd = onPanEnd
                nsView.onMagnify = onMagnify
                nsView.onDoubleClick = onDoubleClick
                nsView.buildContextMenu = buildContextMenu
            }
        }

        private final class PanZoomNSView: NSView {
            var onPan: ((CGSize) -> Void)?
            var onPanEnd: (() -> Void)?
            var onMagnify: ((CGFloat, CGPoint) -> Void)?
            var onDoubleClick: ((CGPoint) -> Void)?
            var buildContextMenu: (() -> NSMenu)?

            private var lastMousePoint: NSPoint?

            override var acceptsFirstResponder: Bool { true }

            override func scrollWheel(with event: NSEvent) {
                onPan?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
                if event.phase == .ended || event.momentumPhase == .ended {
                    onPanEnd?()
                }
            }

            override func magnify(with event: NSEvent) {
                let scale = 1 + event.magnification
                let location = convert(event.locationInWindow, from: nil)
                onMagnify?(scale, location)
            }

            override func mouseDown(with event: NSEvent) {
                let point = convert(event.locationInWindow, from: nil)
                if event.clickCount == 2 {
                    onDoubleClick?(point)
                    return
                }
                lastMousePoint = point
            }

            override func mouseDragged(with event: NSEvent) {
                let point = convert(event.locationInWindow, from: nil)
                if let last = lastMousePoint {
                    onPan?(CGSize(width: point.x - last.x, height: point.y - last.y))
                }
                lastMousePoint = point
            }

            override func mouseUp(with event: NSEvent) {
                lastMousePoint = nil
                onPanEnd?()
            }

            override func rightMouseDown(with event: NSEvent) {
                if let menu = buildContextMenu?() {
                    NSMenu.popUpContextMenu(menu, with: event, for: self)
                } else {
                    super.rightMouseDown(with: event)
                }
            }
        }

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
                openPostPageAction: { NSWorkspace.shared.open(pageURL) },
                openLargeAction: { if let u = post.largeURL { NSWorkspace.shared.open(u) } },
                openOriginalAction: { if let u = post.fileURL { NSWorkspace.shared.open(u) } },
                copyTagsAction: { copyTagsToPasteboard() },
                copyPostURLAction: { copyPostURL() },
                copyOriginalURLAction: { copyOriginalURL() },
                copyImageAction: { Task { await copyImageToPasteboard() } },
                copySourceURLAction: { copySourceURL() },
                downloadAction: { Task { await downloadBestImage() } },
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

        private final class MenuActionTarget: NSObject {
            static var associatedKey: UInt8 = 0
            let fitAction: () -> Void
            let zoomInAction: () -> Void
            let zoomOutAction: () -> Void
            let centerAction: () -> Void
            let openPostPageAction: () -> Void
            let openLargeAction: () -> Void
            let openOriginalAction: () -> Void
            let copyTagsAction: () -> Void
            let copyPostURLAction: () -> Void
            let copyOriginalURLAction: () -> Void
            let copyImageAction: () -> Void
            let copySourceURLAction: () -> Void
            let downloadAction: () -> Void
            let revealDownloadsFolderAction: () -> Void

            init(
                fitAction: @escaping () -> Void,
                zoomInAction: @escaping () -> Void,
                zoomOutAction: @escaping () -> Void,
                centerAction: @escaping () -> Void,
                openPostPageAction: @escaping () -> Void,
                openLargeAction: @escaping () -> Void,
                openOriginalAction: @escaping () -> Void,
                copyTagsAction: @escaping () -> Void,
                copyPostURLAction: @escaping () -> Void,
                copyOriginalURLAction: @escaping () -> Void,
                copyImageAction: @escaping () -> Void,
                copySourceURLAction: @escaping () -> Void,
                downloadAction: @escaping () -> Void,
                revealDownloadsFolderAction: @escaping () -> Void
            ) {
                self.fitAction = fitAction
                self.zoomInAction = zoomInAction
                self.zoomOutAction = zoomOutAction
                self.centerAction = centerAction
                self.openPostPageAction = openPostPageAction
                self.openLargeAction = openLargeAction
                self.openOriginalAction = openOriginalAction
                self.copyTagsAction = copyTagsAction
                self.copyPostURLAction = copyPostURLAction
                self.copyOriginalURLAction = copyOriginalURLAction
                self.copyImageAction = copyImageAction
                self.copySourceURLAction = copySourceURLAction
                self.downloadAction = downloadAction
                self.revealDownloadsFolderAction = revealDownloadsFolderAction
            }

            @objc func fit() { fitAction() }
            @objc func zoomIn() { zoomInAction() }
            @objc func zoomOut() { zoomOutAction() }
            @objc func center() { centerAction() }
            @objc func openPostPage() { openPostPageAction() }
            @objc func openLarge() { openLargeAction() }
            @objc func openOriginal() { openOriginalAction() }
            @objc func copyTags() { copyTagsAction() }
            @objc func copyPostURL() { copyPostURLAction() }
            @objc func copyOriginalURL() { copyOriginalURLAction() }
            @objc func copyImage() { copyImageAction() }
            @objc func copySourceURL() { copySourceURLAction() }
            @objc func download() { downloadAction() }
            @objc func revealDownloadsFolder() { revealDownloadsFolderAction() }
        }
    #endif
}
