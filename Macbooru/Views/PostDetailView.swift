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

    private let commentsPageSize = 40

    private let imageCornerRadius: CGFloat = 24

    private var bestImageCandidates: [URL] {
        [post.largeURL, post.fileURL, post.previewURL].compactMap { $0 }
    }
    private var pageURL: URL { URL(string: "https://danbooru.donmai.us/posts/\(post.id)")! }

    private var openMenu: some View {
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
            ActionChip(title: "Open", systemImage: "safari", tint: .cyan)
        }
        .menuStyle(.borderlessButton)
    }

    private var copyMenu: some View {
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
            ActionChip(title: "Copy", systemImage: "doc.on.doc", tint: .mint)
        }
        .menuStyle(.borderlessButton)
    }

    private var interactMenu: some View {
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
            ActionChip(title: "Interact", systemImage: "hand.tap", tint: .pink)
        }
        .menuStyle(.borderlessButton)
        .disabled(!dependenciesStore.hasCredentials)
        .help(
            dependenciesStore.hasCredentials
                ? "Избранное и голосование"
                : "Укажите учетные данные Danbooru в настройках"
        )
    }

    private var moreMenu: some View {
        Menu {
            Button("Reveal Downloads Folder", systemImage: "folder") {
                revealDownloadsFolder()
            }
        } label: {
            ActionChip(title: "More", systemImage: "ellipsis.circle", tint: Theme.ColorPalette.textMuted)
        }
        .menuStyle(.borderlessButton)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            // Левая колонка — изображение + действия
            VStack(alignment: .leading, spacing: 20) {
                ZStack(alignment: .topTrailing) {
                    GeometryReader { proxy in
                        let h = max(420.0, proxy.size.height)
                        RemoteImage(
                            candidates: bestImageCandidates,
                            height: h,
                            contentMode: ContentMode.fit,
                            animateFirstAppearance: true,
                            animateUpgrades: true,
                            decoratedBackground: false,
                            cornerRadius: imageCornerRadius
                        )
                        .scaleEffect(zoom)
                        .offset(offset)
                        .onChange(of: zoom) { _, _ in
                            // При изменении зума (в т.ч. кнопками) удерживаем изображение в пределах рамки
                            offset = clampedOffset(
                                offset, containerSize: proxy.size, contentBaseHeight: h)
                        }
                        #if os(macOS)
                            // macOS: захватываем жесты трекпада через AppKit-представление поверх
                            .overlay(
                                PanZoomProxy(
                                    onPan: { delta in
                                        // Панорамирование с ограничением в рамках области просмотра
                                        let candidate = CGSize(
                                            width: offset.width + delta.width,
                                            height: offset.height + delta.height
                                        )
                                        offset = softClampedOffset(
                                            candidate, containerSize: proxy.size,
                                            contentBaseHeight: h)
                                        lastDrag = offset
                                    },
                                    onPanEnd: {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            offset = hardClampedOffset(
                                                offset, containerSize: proxy.size,
                                                contentBaseHeight: h)
                                        }
                                        lastDrag = offset
                                    },
                                    onMagnify: { scale, location in
                                        let old = zoom
                                        let next = min(6.0, max(0.5, old * scale))
                                        // удерживаем фокус: корректируем offset так, чтобы точка под курсором оставалась на месте
                                        if old != 0, next != old {
                                            let f = next / old
                                            let center = CGPoint(
                                                x: proxy.size.width / 2,
                                                y: proxy.size.height / 2
                                            )
                                            let dx = (location.x - center.x) * (f - 1)
                                            let dy = (location.y - center.y) * (f - 1)
                                            offset = CGSize(
                                                width: offset.width - dx,
                                                height: offset.height - dy
                                            )
                                        }
                                        zoom = next
                                        lastZoom = next
                                        // после изменения зума — подправим оффсет к жёстким пределам
                                        offset = hardClampedOffset(
                                            offset, containerSize: proxy.size,
                                            contentBaseHeight: h)
                                    },
                                    onDoubleClick: { _ in
                                        // Fit по двойному клику
                                        resetZoom()
                                    },
                                    buildContextMenu: { makeArtContextMenu() }
                                )
                            )
                        #else
                            // iOS: стандартные жесты SwiftUI
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
                                            candidate, containerSize: proxy.size,
                                            contentBaseHeight: h)
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            offset = hardClampedOffset(
                                                offset, containerSize: proxy.size,
                                                contentBaseHeight: h)
                                        }
                                        lastDrag = offset
                                    }
                            )
                        #endif
                        .animation(Animation.easeInOut(duration: 0.15), value: zoom)
                    }
                    .frame(minHeight: 460)

                    // Плавающие контролы зума
                    HStack(spacing: 10) {
                        Theme.IconButton(
                            systemName: "arrow.down.right.and.arrow.up.left",
                            action: resetZoom
                        )
                        .help("Сбросить зум и позицию")

                        Theme.IconButton(
                            systemName: "minus.magnifyingglass",
                            action: { stepZoom(in: -1) }
                        )

                        Theme.IconButton(
                            systemName: "plus.magnifyingglass",
                            action: { stepZoom(in: +1) }
                        )
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.ColorPalette.controlBackground)
                            .background(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.ColorPalette.glassBorder, lineWidth: 1)
                    )
                    .padding(12)
                }

                .padding(18)
                .glassCard(cornerRadius: imageCornerRadius, hoverElevates: false)

                ActionsCard(
                    openMenu: { openMenu },
                    copyMenu: { copyMenu },
                    interactMenu: { interactMenu },
                    moreMenu: { moreMenu },
                    onDownload: { Task { await downloadBestImage() } },
                    downloadDisabled: bestImageCandidates.isEmpty
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            // Правая колонка — Info и Tags
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    InfoCard(
                        post: post,
                        favoriteCount: favoriteCount ?? post.favCount,
                        isFavorited: isFavorited,
                        upScore: upScore ?? post.upScore,
                        downScore: downScore ?? post.downScore
                    )

                    // Секции тегов: Artist / Copyright / Characters / General / Meta
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
                .padding(.vertical)
                .frame(maxWidth: 320)
            }
        }
        .padding()
        .background(Theme.Gradients.appBackground.ignoresSafeArea())
        .navigationTitle("Post #\(post.id)")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { copyTagsToPasteboard() }) { Image(systemName: "doc.on.doc") }
                    .help("Copy tags")
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button(action: { Task { await downloadBestImage() } }) {
                    Image(systemName: "tray.and.arrow.down")
                }
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
        guard let url = bestImageCandidates.first else { return }
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

// Контрастный ярлык для Menu-кнопок, чтобы они выглядели как prominent-кнопки
private struct ProminentMenuLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(Color.accentColor)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

extension View {
    fileprivate func prominentMenuLabel() -> some View { self.modifier(ProminentMenuLabel()) }
    @ViewBuilder
    fileprivate func hideMenuIndicatorIfAvailable() -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.menuIndicator(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Rating badge
private struct RatingBadge: View {
    let rating: String
    var body: some View {
        let r = rating.lowercased()
        let color: Color = (r == "g") ? .green : (r == "s") ? .blue : (r == "q") ? .orange : .red
        Text(r.uppercased())
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Flow layout for tags
private struct ActionChip: View {
    let title: String
    let systemImage: String
    var tint: Color
    @State private var hovering = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(hovering ? 0.22 : 0.16))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint.opacity(hovering ? 0.45 : 0.3), lineWidth: 1)
            )
            .foregroundStyle(tint)
            .scaleEffect(hovering ? 1.02 : 1.0)
            .animation(Theme.Animations.interactive, value: hovering)
            .onHover { hovering = $0 }
    }
}

private struct ActionsCard<Open: View, Copy: View, Interact: View, More: View>: View {
    let openMenu: () -> Open
    let copyMenu: () -> Copy
    let interactMenu: () -> Interact
    let moreMenu: () -> More
    let onDownload: () -> Void
    var downloadDisabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            openMenu()
            copyMenu()
            interactMenu()
            moreMenu()
            Spacer()
            Button(action: onDownload) {
                Label("Download", systemImage: "tray.and.arrow.down")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(Theme.GlassButtonStyle(kind: .primary))
            .disabled(downloadDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 20, hoverElevates: false)
    }
}

private struct InfoCard: View {
    let post: Post
    let favoriteCount: Int?
    let isFavorited: Bool?
    let upScore: Int?
    let downScore: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Информация", systemImage: "info.circle")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.ColorPalette.textPrimary)
                Spacer(minLength: 0)
                if let rating = post.rating {
                    RatingChip(rating: rating)
                }
            }

            Divider().opacity(0.08)

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "number", title: "ID", value: "#\(post.id)")

                if let score = post.score {
                    InfoRow(icon: "star.fill", title: "Score", value: "\(score)", tint: .yellow) {
                        ScoreChip(score: score)
                    }
                }

                if let fav = favoriteCount {
                    InfoRow(icon: "heart.fill", title: "Favorites", value: "\(fav)", tint: .pink)
                }

                if let isFav = isFavorited {
                    InfoRow(icon: "heart.circle.fill", title: "In favorites", value: isFav ? "Yes" : "No", tint: .pink)
                }

                if let up = upScore {
                    InfoRow(icon: "hand.thumbsup.fill", title: "Upvotes", value: "\(up)", tint: .green)
                }

                if let down = downScore {
                    InfoRow(icon: "hand.thumbsdown.fill", title: "Downvotes", value: "\(down)", tint: .orange)
                }

                if let width = post.width, let height = post.height {
                    InfoRow(icon: "aspectratio", title: "Size", value: "\(width) × \(height)", tint: .cyan) {
                        SizeBadge(width: width, height: height)
                    }
                }

                if let date = post.createdAt {
                    InfoRow(
                        icon: "calendar",
                        title: "Created",
                        value: date.formatted(date: .abbreviated, time: .shortened),
                        tint: .blue
                    )
                }
            }

            if let src = post.source, let url = URL(string: src) {
                Divider().opacity(0.08)
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                        Text("Open source")
                            .font(.callout.weight(.semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.ColorPalette.accent)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 20, hoverElevates: false)
    }
}

private struct InfoRow<Accessory: View>: View {
    let icon: String
    let title: String
    let value: String
    var tint: Color
    @ViewBuilder var accessory: () -> Accessory

    init(
        icon: String,
        title: String,
        value: String,
        tint: Color = Theme.ColorPalette.accent,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.tint = tint
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                )
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.ColorPalette.textMuted)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.ColorPalette.textPrimary)
            }

            Spacer(minLength: 0)

            accessory()
        }
    }
}

extension InfoRow where Accessory == EmptyView {
    init(icon: String, title: String, value: String, tint: Color = Theme.ColorPalette.accent) {
        self.init(icon: icon, title: title, value: value, tint: tint) { EmptyView() }
    }
}

private struct TagsCard: View {
    let post: Post
    var onOpenTag: (String) -> Void
    var onCopyTag: (String) -> Void

    private var hasCategorizedSections: Bool {
        !(post.tagsArtist.isEmpty && post.tagsCopyright.isEmpty && post.tagsCharacter.isEmpty
            && post.tagsGeneral.isEmpty && post.tagsMeta.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Теги", systemImage: "tag")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.ColorPalette.textPrimary)
                Spacer(minLength: 0)
                if !post.allTags.isEmpty {
                    Text("\(post.allTags.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ColorPalette.textMuted)
                }
            }

            Divider().opacity(0.08)

            if hasCategorizedSections {
                VStack(alignment: .leading, spacing: 16) {
                    if !post.tagsArtist.isEmpty {
                        TagSection(
                            title: "Artist",
                            color: .purple,
                            tags: post.tagsArtist,
                            onOpenTag: onOpenTag,
                            onCopyTag: onCopyTag
                        )
                    }
                    if !post.tagsCopyright.isEmpty {
                        TagSection(
                            title: "Copyright",
                            color: .teal,
                            tags: post.tagsCopyright,
                            onOpenTag: onOpenTag,
                            onCopyTag: onCopyTag
                        )
                    }
                    if !post.tagsCharacter.isEmpty {
                        TagSection(
                            title: "Characters",
                            color: .orange,
                            tags: post.tagsCharacter,
                            onOpenTag: onOpenTag,
                            onCopyTag: onCopyTag
                        )
                    }
                    if !post.tagsGeneral.isEmpty {
                        TagSection(
                            title: "General",
                            color: .secondary,
                            tags: post.tagsGeneral,
                            onOpenTag: onOpenTag,
                            onCopyTag: onCopyTag
                        )
                    }
                    if !post.tagsMeta.isEmpty {
                        TagSection(
                            title: "Meta",
                            color: .pink,
                            tags: post.tagsMeta,
                            onOpenTag: onOpenTag,
                            onCopyTag: onCopyTag
                        )
                    }
                }
            } else if !post.allTags.isEmpty {
                TagFlowView(
                    tags: post.allTags,
                    tint: Theme.ColorPalette.accent,
                    onOpenTag: { onOpenTag($0) },
                    onCopyTag: { onCopyTag($0) }
                )
            } else {
                Text("No tags")
                    .font(.callout)
                    .foregroundStyle(Theme.ColorPalette.textMuted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 20, hoverElevates: false)
    }
}

private struct CommentsCard: View {
    let comments: [Comment]
    let isLoading: Bool
    let error: String?
    let hasMore: Bool
    let isLoadingMore: Bool
    @Binding var newComment: String
    let isSubmitting: Bool
    let canSubmit: Bool
    let onReload: () -> Void
    let onLoadMore: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Комментарии", systemImage: "text.bubble")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.ColorPalette.textPrimary)
                Spacer(minLength: 0)
                Theme.IconButton(
                    systemName: "arrow.clockwise",
                    isDisabled: isLoading,
                    action: onReload
                )
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading comments…")
                        .font(.callout)
                        .foregroundStyle(Theme.ColorPalette.textMuted)
                }
            } else if let error {
                VStack(alignment: .leading, spacing: 10) {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(Theme.ColorPalette.textMuted)
                    Button(action: onReload) {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(Theme.GlassButtonStyle(kind: .secondary))
                }
            } else if comments.isEmpty {
                Text("No comments yet")
                    .font(.callout)
                    .foregroundStyle(Theme.ColorPalette.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                        if comment.id != comments.last?.id {
                            Divider().opacity(0.1)
                        }
                    }
                }
            }

            if hasMore {
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    Button(action: onLoadMore) {
                        Label("Загрузить ещё", systemImage: "chevron.down")
                            .font(.callout.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(Theme.GlassButtonStyle(kind: .secondary))
                }
            }

            Divider().opacity(0.08)

            VStack(alignment: .leading, spacing: 10) {
                Text("Add Comment")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ColorPalette.textPrimary)

                TextEditor(text: $newComment)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.ColorPalette.controlBackground)
                            .background(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.ColorPalette.glassBorder, lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Button(action: onSubmit) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Label("Post", systemImage: "paperplane")
                                .font(.callout.weight(.semibold))
                        }
                    }
                    .buttonStyle(Theme.GlassButtonStyle(kind: .primary))
                    .disabled(
                        isSubmitting
                            || newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !canSubmit
                    )
                }

                Text(
                    canSubmit ? "Не забудьте соблюдать правила сообщества." : "Для отправки комментариев добавьте креды Danbooru в настройках."
                )
                .font(.caption)
                .foregroundStyle(Theme.ColorPalette.textMuted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 20, hoverElevates: false)
    }
}

private struct TagFlowView: View {
    let tags: [String]
    var tint: Color
    var onOpenTag: ((String) -> Void)? = nil
    var onCopyTag: ((String) -> Void)? = nil

    var body: some View {
        Group {
            if #available(macOS 13.0, iOS 16.0, *) {
                FlowLayout(alignment: .leading, spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(
                            tag: tag,
                            title: tag.replacingOccurrences(of: "_", with: " "),
                            tint: tint,
                            onOpen: { onOpenTag?(tag) },
                            onCopy: { onCopyTag?(tag) }
                        )
                    }
                }
            } else {
                // Fallback: адаптивная сетка
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(
                            tag: tag,
                            title: tag.replacingOccurrences(of: "_", with: " "),
                            tint: tint,
                            onOpen: { onOpenTag?(tag) },
                            onCopy: { onCopyTag?(tag) }
                        )
                    }
                }
            }
        }
    }
}

private struct TagChip: View {
    let tag: String
    let title: String
    var tint: Color
    var onOpen: (() -> Void)?
    var onCopy: (() -> Void)?

    var body: some View {
        #if os(macOS)
            Button(action: { onOpen?() }) {
                chipContent
            }
            .buttonStyle(.plain)
            .help("Left click: search in app; Right click: copy tag")
            .overlay(
                RightClickCatcher(onRightClick: { onCopy?() })
                    .allowsHitTesting(true)
            )
        #else
            Button(action: { onOpen?() }) {
                chipContent
            }
            .buttonStyle(.plain)
        #endif
    }

    private var chipContent: some View {
        Text(title)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.18))
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1)
            )
            .foregroundStyle(tint)
    }
}

#if os(macOS)
    // NSViewRepresentable, чтобы отлавливать правый клик поверх SwiftUI Button
    private struct RightClickCatcher: NSViewRepresentable {
        var onRightClick: () -> Void

        func makeNSView(context: Context) -> RightClickCatcherView {
            let v = RightClickCatcherView()
            v.onRightClick = onRightClick
            v.translatesAutoresizingMaskIntoConstraints = false
            return v
        }

        func updateNSView(_ nsView: RightClickCatcherView, context: Context) {
            nsView.onRightClick = onRightClick
        }
    }

    private final class RightClickCatcherView: NSView {
        var onRightClick: (() -> Void)?
        override func hitTest(_ point: NSPoint) -> NSView? {
            // Пропускаем ЛКМ, обрабатываем только ПКМ/прочие
            if let ev = NSApp.currentEvent {
                switch ev.type {
                case .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
                    return self
                case .leftMouseDown, .leftMouseUp:
                    if ev.modifierFlags.contains(.control) { return self }
                    return nil
                default:
                    return nil
                }
            }
            return nil
        }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) {
                onRightClick?()
            } else {
                super.mouseDown(with: event)
            }
        }
        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
        }
    }
#endif

// Универсальный FlowLayout на основе Layout API (macOS 13+)
@available(macOS 13.0, iOS 16.0, *)
private struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if width + size.width > maxWidth {
                height += lineHeight + spacing
                width = 0
                lineHeight = 0
            }
            width += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        height += lineHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Комментарии
private struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Theme.ColorPalette.controlBackground.opacity(0.9))
                .overlay(
                    Text(avatarInitial)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.ColorPalette.textPrimary)
                )
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(authorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ColorPalette.textPrimary)
                    if let creatorID = comment.creatorID {
                        Text("#\(creatorID)")
                            .font(.caption)
                            .foregroundStyle(Theme.ColorPalette.textMuted)
                    }
                    Spacer(minLength: 0)
                    if let date = comment.createdAt {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.ColorPalette.textMuted)
                    }
                }
                if let attributed = renderedBody {
                    Text(attributed)
                        .font(.callout)
                        .foregroundStyle(Theme.ColorPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(comment.body)
                        .font(.callout)
                        .foregroundStyle(Theme.ColorPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.ColorPalette.controlBackground.opacity(0.95))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.ColorPalette.glassBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private var authorName: String {
        if let name = comment.creatorName, !name.isEmpty { return name }
        return "Anonymous"
    }

    private var avatarInitial: String {
        String(authorName.prefix(1)).uppercased()
    }

    private var renderedBody: AttributedString? {
        guard !comment.body.isEmpty else { return nil }
        let markdown = sanitizeBBCode(comment.body)
        return try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
    }

    private func sanitizeBBCode(_ text: String) -> String {
        var output = text
        output = output.replacingOccurrences(of: "[spoiler]", with: "||")
        output = output.replacingOccurrences(of: "[/spoiler]", with: "||")
        output = output.replacingOccurrences(of: "[quote]", with: "> ")
        output = output.replacingOccurrences(of: "[/quote]", with: "\n")
        return output
    }
}

// MARK: - Секция тегов
private struct TagSection: View {
    let title: String
    let color: Color
    let tags: [String]
    var onOpenTag: ((String) -> Void)? = nil
    var onCopyTag: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(color.opacity(0.4), lineWidth: 1)
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "tag")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(color)
                    )

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ColorPalette.textPrimary)

                Spacer(minLength: 0)

                #if os(macOS)
                    Theme.IconButton(
                        systemName: "doc.on.doc",
                        size: 28,
                        isDisabled: tags.isEmpty
                    ) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(tags.joined(separator: " "), forType: .string)
                    }
                    .help("Copy section tags")
                #endif
            }
            TagFlowView(
                tags: tags,
                tint: color,
                onOpenTag: onOpenTag,
                onCopyTag: onCopyTag
            )
        }
    }
}

#if os(macOS)
    // MARK: - Панорамирование и зум (трекпад + мышь) через AppKit
    private struct PanZoomProxy: NSViewRepresentable {
        typealias NSViewType = PanZoomNSView
        var onPan: (CGSize) -> Void
        var onPanEnd: (() -> Void)? = nil
        var onMagnify: (CGFloat, CGPoint) -> Void
        var onDoubleClick: ((CGPoint) -> Void)? = nil
        var buildContextMenu: (() -> NSMenu)? = nil

        func makeNSView(context: Context) -> PanZoomNSView {
            let v = PanZoomNSView()
            v.onPan = onPan
            v.onPanEnd = onPanEnd
            v.onMagnify = onMagnify
            v.onDoubleClick = onDoubleClick
            v.buildContextMenu = buildContextMenu
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.clear.cgColor
            return v
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
            // Завершение жеста скролла/панорамирования
            if event.phase == .ended || event.momentumPhase == .ended {
                onPanEnd?()
            }
        }

        override func magnify(with event: NSEvent) {
            let scale = 1 + event.magnification
            let p = convert(event.locationInWindow, from: nil)
            onMagnify?(scale, p)
        }

        override func mouseDown(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            if event.clickCount == 2 {
                onDoubleClick?(p)
                return
            }
            lastMousePoint = p
        }

        override func mouseDragged(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            if let last = lastMousePoint {
                let dx = p.x - last.x
                let dy = p.y - last.y
                onPan?(CGSize(width: dx, height: dy))
            }
            lastMousePoint = p
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
#endif
