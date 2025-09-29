import SwiftUI

// Types Post и RemoteImage должны быть в том же таргете. Импорт доп. модулей не требуется.

#if os(macOS)
    import AppKit
#endif

struct PostDetailView: View {
    let post: Post
    @EnvironmentObject private var search: SearchState
    @Environment(\.dismiss) private var dismiss

    // Зум и панорамирование
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var saveMessage: String? = nil

    private var bestImageCandidates: [URL] {
        [post.largeURL, post.fileURL, post.previewURL].compactMap { $0 }
    }
    private var pageURL: URL { URL(string: "https://danbooru.donmai.us/posts/\(post.id)")! }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            // Левая колонка — изображение + действия
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    GeometryReader { proxy in
                        let h = max(420.0, proxy.size.height)
                        RemoteImage(
                            candidates: bestImageCandidates,
                            height: h,
                            contentMode: ContentMode.fit,
                            animateFirstAppearance: true,
                            animateUpgrades: true
                        )
                        .scaleEffect(zoom)
                        .offset(offset)
                        .onChange(of: zoom) { _ in
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
                                        offset = clampedOffset(
                                            candidate, containerSize: proxy.size,
                                            contentBaseHeight: h)
                                        lastDrag = offset
                                    },
                                    onMagnify: { scale in
                                        let new = min(6.0, max(0.5, zoom * scale))
                                        zoom = new
                                        lastZoom = new
                                        // после изменения зума — скорректировать оффсет в допустимые пределы
                                        offset = clampedOffset(
                                            offset, containerSize: proxy.size, contentBaseHeight: h)
                                    }
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
                                        offset = clampedOffset(
                                            candidate, containerSize: proxy.size,
                                            contentBaseHeight: h)
                                    }
                                    .onEnded { _ in
                                        lastDrag = offset
                                    }
                            )
                        #endif
                        .animation(Animation.easeInOut(duration: 0.15), value: zoom)
                    }
                    .frame(minHeight: 460)

                    // Плавающие контролы зума
                    HStack(spacing: 8) {
                        Button {
                            resetZoom()
                        } label: {
                            Label("Fit", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        .help("Сбросить зум и позицию")
                        Button {
                            stepZoom(in: -1)
                        } label: {
                            Label("-", systemImage: "minus.magnifyingglass")
                        }
                        Button {
                            stepZoom(in: +1)
                        } label: {
                            Label("+", systemImage: "plus.magnifyingglass")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.callout)
                    .padding(8)
                }

                // Действия
                HStack(spacing: 12) {
                    if let url = post.fileURL {
                        Link(destination: url) { Label("Open original", systemImage: "safari") }
                    }
                    if let url = post.largeURL {
                        Link(destination: url) { Label("Open large", systemImage: "safari") }
                    }
                    Link(destination: pageURL) { Label("Open post page", systemImage: "link") }
                    Button {
                        copyTagsToPasteboard()
                    } label: {
                        Label("Copy tags", systemImage: "doc.on.doc")
                    }
                    Button {
                        Task { await downloadBestImage() }
                    } label: {
                        Label("Download", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(bestImageCandidates.isEmpty)
                    Spacer()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.callout)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            // Правая колонка — Info и Tags
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GroupBox("Info") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ID:")
                                Text("#\(post.id)").bold()
                                Spacer()
                                if let r = post.rating { RatingBadge(rating: r) }
                            }
                            if let w = post.width, let h = post.height {
                                HStack {
                                    Text("Size:")
                                    Text("\(w)x\(h)")
                                }
                            }
                            if let score = post.score {
                                HStack {
                                    Text("Score:")
                                    Text("\(score)")
                                }
                            }
                            if let fav = post.favCount {
                                HStack {
                                    Text("Favs:")
                                    Text("\(fav)")
                                }
                            }
                            if let date = post.createdAt {
                                HStack {
                                    Text("Created:")
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                }
                            }
                            if let src = post.source, let url = URL(string: src) {
                                Link("Source", destination: url)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.callout)
                    .padding(8)
                    .background(
                        .regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(
                            .quinary, lineWidth: 1))

                    // Секции тегов: Artist / Copyright / Characters / General / Meta
                    if !(post.tagsArtist.isEmpty && post.tagsCopyright.isEmpty
                        && post.tagsCharacter.isEmpty && post.tagsGeneral.isEmpty
                        && post.tagsMeta.isEmpty)
                    {
                        GroupBox("Tags") {
                            VStack(alignment: .leading, spacing: 12) {
                                if !post.tagsArtist.isEmpty {
                                    TagSection(
                                        title: "Artist", color: .purple, tags: post.tagsArtist,
                                        onOpenTag: { tag in openSearchInApp(tag) },
                                        onCopyTag: { tag in copySingleTag(tag) }
                                    )
                                }
                                if !post.tagsCopyright.isEmpty {
                                    TagSection(
                                        title: "Copyright", color: .teal, tags: post.tagsCopyright,
                                        onOpenTag: { tag in openSearchInApp(tag) },
                                        onCopyTag: { tag in copySingleTag(tag) }
                                    )
                                }
                                if !post.tagsCharacter.isEmpty {
                                    TagSection(
                                        title: "Characters", color: .orange,
                                        tags: post.tagsCharacter,
                                        onOpenTag: { tag in openSearchInApp(tag) },
                                        onCopyTag: { tag in copySingleTag(tag) }
                                    )
                                }
                                if !post.tagsGeneral.isEmpty {
                                    TagSection(
                                        title: "General", color: .secondary, tags: post.tagsGeneral,
                                        onOpenTag: { tag in openSearchInApp(tag) },
                                        onCopyTag: { tag in copySingleTag(tag) }
                                    )
                                }
                                if !post.tagsMeta.isEmpty {
                                    TagSection(
                                        title: "Meta", color: .pink, tags: post.tagsMeta,
                                        onOpenTag: { tag in openSearchInApp(tag) },
                                        onCopyTag: { tag in copySingleTag(tag) }
                                    )
                                }
                            }
                            .font(.callout)
                        }
                        .padding(8)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(
                                .quinary, lineWidth: 1))
                    } else {
                        GroupBox("Tags") {
                            if !post.allTags.isEmpty {
                                TagFlowView(
                                    tags: post.allTags,
                                    onOpenTag: { tag in openSearchInApp(tag) },
                                    onCopyTag: { tag in copySingleTag(tag) }
                                )
                            } else {
                                Text("No tags").foregroundStyle(.secondary)
                            }
                        }
                        .font(.callout)
                        .padding(8)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(
                                .quinary, lineWidth: 1))
                    }
                }
                .padding(.vertical)
                .frame(maxWidth: 320)
            }
        }
        .padding()
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
private struct TagFlowView: View {
    let tags: [String]
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
    var onOpen: (() -> Void)?
    var onCopy: (() -> Void)?

    var body: some View {
        #if os(macOS)
            Button(action: { onOpen?() }) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thickMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.quinary, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Left click: search in app; Right click: copy tag")
            // ПКМ ловим поверх, но пропускаем ЛКМ
            .overlay(
                RightClickCatcher(onRightClick: { onCopy?() })
                    .allowsHitTesting(true)
            )
        #else
            Button(action: { onOpen?() }) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thickMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.quinary, lineWidth: 1))
            }
            .buttonStyle(.plain)
        #endif
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

// MARK: - Секция тегов
private struct TagSection: View {
    let title: String
    let color: Color
    let tags: [String]
    var onOpenTag: ((String) -> Void)? = nil
    var onCopyTag: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(color.opacity(0.8)).frame(width: 6, height: 6)
                Text(title).font(.headline).fontWeight(.semibold).foregroundStyle(.primary)
                Spacer()
                #if os(macOS)
                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(tags.joined(separator: " "), forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy section tags")
                #endif
            }
            TagFlowView(tags: tags, onOpenTag: onOpenTag, onCopyTag: onCopyTag)
        }
    }
}

#if os(macOS)
    // MARK: - Панорамирование и зум (трекпад) через AppKit
    private struct PanZoomProxy: NSViewRepresentable {
        typealias NSViewType = PanZoomNSView
        var onPan: (CGSize) -> Void
        var onMagnify: (CGFloat) -> Void

        func makeNSView(context: Context) -> PanZoomNSView {
            let v = PanZoomNSView()
            v.onPan = onPan
            v.onMagnify = onMagnify
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.clear.cgColor
            return v
        }

        func updateNSView(_ nsView: PanZoomNSView, context: Context) {
            nsView.onPan = onPan
            nsView.onMagnify = onMagnify
        }
    }

    private final class PanZoomNSView: NSView {
        var onPan: ((CGSize) -> Void)?
        var onMagnify: ((CGFloat) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            onPan?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
        }

        override func magnify(with event: NSEvent) {
            let scale = 1 + event.magnification
            onMagnify?(scale)
        }
    }
#endif
