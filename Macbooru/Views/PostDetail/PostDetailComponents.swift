import SwiftUI

struct ActionChip: View {
    enum ChipState {
        case normal
        case loading
        case disabled
    }

    let title: String
    let systemImage: String
    var tint: Color
    var state: ChipState = .normal
    var accessibilityHint: String? = nil

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            if state == .loading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(title)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(foregroundColor)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(backgroundOpacity))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(borderOpacity), lineWidth: 1)
        )
        .scaleEffect(hovering && state == .normal ? 1.02 : 1.0)
        .animation(Theme.Animations.interactive(), value: hovering)
        .onHover { value in
            guard state == .normal else { return }
            withAnimation(Theme.Animations.hover()) {
                hovering = value
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(accessibilityValueText))
        .accessibilityHint(Text(resolvedHint ?? ""))
        .accessibilityAddTraits(.isButton)
    }

    private var foregroundColor: Color {
        state == .disabled ? tint.opacity(0.4) : tint
    }

    private var backgroundOpacity: Double {
        switch state {
        case .normal: return hovering ? 0.22 : 0.16
        case .loading: return 0.22
        case .disabled: return 0.12
        }
    }

    private var borderOpacity: Double {
        switch state {
        case .normal: return hovering ? 0.45 : 0.3
        case .loading: return 0.4
        case .disabled: return 0.18
        }
    }

    private var accessibilityValueText: String {
        state == .loading ? "Loading" : ""
    }

    private var resolvedHint: String? {
        if let accessibilityHint {
            return accessibilityHint
        }
        switch state {
        case .disabled:
            return "Currently unavailable"
        case .loading:
            return "In progress"
        default:
            return nil
        }
    }
}

struct ActionsCard<Open: View, Copy: View, Interact: View, More: View>: View {
    let openMenu: () -> Open
    let copyMenu: () -> Copy
    let interactMenu: () -> Interact
    let moreMenu: () -> More
    let onDownload: () -> Void
    var downloadDisabled: Bool
    var isDownloading: Bool

    var body: some View {
        HStack(spacing: 12) {
            openMenu()
            copyMenu()
            interactMenu()
            moreMenu()
            Spacer(minLength: 0)
            Button(action: onDownload) {
                HStack(spacing: 8) {
                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(isDownloading ? "Saving…" : "Download")
                        .font(.callout.weight(.semibold))
                }
            }
            .buttonStyle(Theme.GlassButtonStyle(kind: .primary))
            .disabled(downloadDisabled || isDownloading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 20, hoverElevates: false)
    }
}

struct InfoCard: View {
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
                    InfoRow(
                        icon: "heart.circle.fill",
                        title: "In favorites",
                        value: isFav ? "Yes" : "No",
                        tint: .pink
                    )
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

struct InfoRow<Accessory: View>: View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }
}

extension InfoRow where Accessory == EmptyView {
    init(icon: String, title: String, value: String, tint: Color = Theme.ColorPalette.accent) {
        self.init(icon: icon, title: title, value: value, tint: tint) { EmptyView() }
    }
}

struct TagsCard: View {
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

struct TagSection: View {
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

struct TagFlowView: View {
    let tags: [String]
    var tint: Color
    var onOpenTag: ((String) -> Void)? = nil
    var onCopyTag: ((String) -> Void)? = nil

    var body: some View {
        Group {
            if #available(macOS 13.0, iOS 16.0, *) {
                ChipsFlowLayout(spacing: 6, rowSpacing: 6) {
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
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80), spacing: 6)],
                    alignment: .leading,
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

struct TagChip: View {
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
            .help("Left click to search, right click to copy")
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
            .accessibilityElement()
            .accessibilityLabel(Text("Tag \(title)"))
            .accessibilityHint(Text("Double tap to search."))
    }
}

struct CommentsCard: View {
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
                    .accessibilityHint("Enter your comment")

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
                    canSubmit
                        ? "Не забудьте соблюдать правила сообщества."
                        : "Для отправки комментариев добавьте креды Danbooru в настройках."
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

struct CommentRow: View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Comment by \(authorName)"))
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

#if os(macOS)
import AppKit

struct RightClickCatcher: NSViewRepresentable {
    var onRightClick: () -> Void

    func makeNSView(context: Context) -> RightClickCatcherView {
        let view = RightClickCatcherView()
        view.onRightClick = onRightClick
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: RightClickCatcherView, context: Context) {
        nsView.onRightClick = onRightClick
    }
}

final class RightClickCatcherView: NSView {
    var onRightClick: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        switch event.type {
        case .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
            return self
        case .leftMouseDown, .leftMouseUp:
            if event.modifierFlags.contains(.control) { return self }
            return nil
        default:
            return nil
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.type == .otherMouseDown || event.type == .rightMouseDown {
            onRightClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
#endif
