import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PostDetailView: View {
    let post: Post

    // Зум и панорамирование для изображения
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var isSaving = false
    @State private var saveMessage: String? = nil

    private var bestImageCandidates: [URL] {
        // Порядок: large -> original -> preview (быстрый фоллбек)
        [post.largeURL, post.fileURL, post.previewURL].compactMap { $0 }
    }

    private var pageURL: URL { URL(string: "https://danbooru.donmai.us/posts/\(post.id)")! }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            // Левая панель — просмотр изображения
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    GeometryReader { proxy in
                        let h = max(420.0, proxy.size.height)
                        RemoteImage(
                            candidates: bestImageCandidates,
                            height: h,
                            contentMode: .fit,
                            animateFirstAppearance: true,
                            animateUpgrades: true
                        )
                        .scaleEffect(zoom)
                        .offset(offset)
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
                                    offset = CGSize(width: lastDrag.width + g.translation.width, height: lastDrag.height + g.translation.height)
                                }
                                .onEnded { _ in
                                    lastDrag = offset
                                }
                        )
                        .animation(.snappy(duration: 0.15), value: zoom)
                    }
                    .frame(minHeight: 460)

                    // Плавающая панель управления зумом
                    HStack(spacing: 8) {
                        Button { resetZoom() } label: { Label("Fit", systemImage: "arrow.down.right.and.arrow.up.left") }
                            .help("Сбросить зум и позицию")
                        Button { stepZoom(in: -1) } label: { Label("-", systemImage: "minus.magnifyingglass") }
                        Button { stepZoom(in: +1) } label: { Label("+", systemImage: "plus.magnifyingglass") }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(8)
                }

                // Действия под изображением
                HStack(spacing: 12) {
                    if let url = post.fileURL { Link(destination: url) { Label("Open original", systemImage: "safari") } }
                    if let url = post.largeURL { Link(destination: url) { Label("Open large", systemImage: "safari") } }
                    Link(destination: pageURL) { Label("Open post page", systemImage: "link") }
                    Button { copyTagsToPasteboard() } label: { Label("Copy tags", systemImage: "doc.on.doc") }
                    Button { Task { await downloadBestImage() } } label: { Label("Download", systemImage: "tray.and.arrow.down") }
                        .disabled(bestImageCandidates.isEmpty)
                    Spacer()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            // Правая панель — метаданные и теги
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("Info") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ID:")
                                Text("#\(post.id)").bold()
                                Spacer()
                                if let r = post.rating { RatingBadge(rating: r) }
                            }
                            if let w = post.width, let h = post.height {
                                HStack { Text("Size:"); Text("\(w)x\(h)") }
                            }
                            if let score = post.score {
                                HStack { Text("Score:"); Text("\(score)") }
                            }
                            if let fav = post.favCount {
                                HStack { Text("Favs:"); Text("\(fav)") }
                            }
                            if let date = post.createdAt {
                                HStack { Text("Created:"); Text(date.formatted(date: .abbreviated, time: .shortened)) }
                            }
                            if let src = post.source, let url = URL(string: src) {
                                Link("Source", destination: url)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Tags") {
                        if let tags = post.tagString, !tags.isEmpty {
                            TagFlowView(tags: tags.split(separator: " ").map(String.init))
                        } else {
                            Text("No tags")
                                .foregroundStyle(.secondary)
                        }
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
                Button(action: { Task { await downloadBestImage() } }) { Image(systemName: "tray.and.arrow.down") }
                    .help("Download best image")
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = saveMessage {
                Text(msg)
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
            let downloads = try fm.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let folder = downloads.appendingPathComponent("Macbooru", isDirectory: true)
            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let filename = url.lastPathComponent.isEmpty ? "post-\(post.id).jpg" : url.lastPathComponent
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
        FlowLayout(alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                TagChip(title: tag.replacingOccurrences(of: "_", with: " ")) {
                    copy(tag)
                }
                .contextMenu {
                    Button("Copy tag") { copy(tag) }
                    if let url = URL(string: "https://danbooru.donmai.us/posts?tags=\(tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tag)") {
                        Link("Open tag search", destination: url)
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
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Click to copy tag")
    }
}

// Универсальный FlowLayout на основе Layout API (macOS 13+)
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

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
