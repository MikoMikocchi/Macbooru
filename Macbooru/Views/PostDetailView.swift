import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct PostDetailView: View {
    let post: Post

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
                        #if os(macOS)
                            // macOS: захватываем жесты трекпада через AppKit-представление поверх
                            .overlay(
                                PanZoomProxy(
                                    onPan: { delta in
                                        // инвертируем направление панорамирования, чтобы пальцы и картинка двигались «естественно»
                                        offset = CGSize(
                                            width: offset.width + delta.width,
                                            height: offset.height + delta.height)
                                        lastDrag = offset
                                    },
                                    onMagnify: { scale in
                                        let new = min(6.0, max(0.5, zoom * scale))
                                        zoom = new
                                        lastZoom = new
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
                                        offset = CGSize(
                                            width: lastDrag.width + g.translation.width,
                                            height: lastDrag.height + g.translation.height)
                                    }
                                    .onEnded { _ in
                                        lastDrag = offset
                                    }
                            )
                        #endif
                        .animation(.easeInOut(duration: 0.15), value: zoom)
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
                                        title: "Artist", color: .purple, tags: post.tagsArtist)
                                }
                                if !post.tagsCopyright.isEmpty {
                                    TagSection(
                                        title: "Copyright", color: .teal, tags: post.tagsCopyright)
                                }
                                if !post.tagsCharacter.isEmpty {
                                    TagSection(
                                        title: "Characters", color: .orange,
                                        tags: post.tagsCharacter)
                                }
                                if !post.tagsGeneral.isEmpty {
                                    TagSection(
                                        title: "General", color: .secondary, tags: post.tagsGeneral)
                                }
                                if !post.tagsMeta.isEmpty {
                                    TagSection(title: "Meta", color: .pink, tags: post.tagsMeta)
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
                                TagFlowView(tags: post.allTags)
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
    @State private var copied: String? = nil

    var body: some View {
        Group {
            if #available(macOS 13.0, iOS 16.0, *) {
                FlowLayout(alignment: .leading, spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(title: tag.replacingOccurrences(of: "_", with: " ")) { copy(tag) }
                            .contextMenu {
                                Button("Copy tag") { copy(tag) }
                                if let url = URL(
                                    string:
                                        "https://danbooru.donmai.us/posts?tags=\(tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tag)"
                                ) {
                                    Link("Open tag search", destination: url)
                                }
                            }
                    }
                }
            } else {
                // Fallback: адаптивная сетка
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(title: tag.replacingOccurrences(of: "_", with: " ")) { copy(tag) }
                    }
                }
            }
        }
    }

    private func copy(_ t: String) {
        #if os(macOS)
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(t, forType: .string)
        #endif
    }
}

private struct TagChip: View {
    let title: String
    var onTap: (() -> Void)?
    var body: some View {
        Button(action: { onTap?() }) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thickMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.quinary, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Click to copy tag")
    }
}

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
            TagFlowView(tags: tags)
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
