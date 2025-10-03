import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var dependenciesStore: AppDependenciesStore
    @State private var username: String = ""
    @State private var apiKey: String = ""
    @State private var status: StatusMessage? = nil
    @State private var isSaving = false
    @State private var cacheLimitMB: Double = 256
    @State private var appliedCacheLimitMB: Double = 256
    @State private var cacheUsageMB: Double = 0
    @State private var isUpdatingCacheLimit = false
    @State private var isClearingCache = false

    @AppStorage("settings.autoRefreshOnLaunch") private var autoRefreshOnLaunch: Bool = false
    @AppStorage("settings.showKeyboardHints") private var showKeyboardHints: Bool = true
    @AppStorage("settings.blurSensitiveDefault") private var blurSensitiveDefault: Bool = true

    private var cardColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 320, maximum: 520), spacing: 24)]
    }

    enum StatusMessage: Equatable {
        case success(String)
        case error(String)

        var text: String {
            switch self {
            case .success(let message), .error(let message):
                return message
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 28) {
                credentialsSection
                    .frame(maxWidth: 860)

                LazyVGrid(columns: cardColumns, spacing: 24) {
                    cacheSection
                    generalSection
                    resourcesSection
                    statusSection
                }
                .frame(maxWidth: 860)
            }
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .onAppear(perform: loadFromStore)
        .onAppear(perform: loadCacheSettings)
    }

    private func loadFromStore() {
        username = dependenciesStore.credentials.username ?? ""
        apiKey = dependenciesStore.credentials.apiKey ?? ""
    }

    private func saveCredentials() {
        isSaving = true
        do {
            try dependenciesStore.updateCredentials(username: username, apiKey: apiKey)
            status = .success(
                dependenciesStore.hasCredentials ? "Данные сохранены" : "Данные очищены")
            isSaving = false
        } catch {
            status = .error("Не удалось сохранить: \(error.localizedDescription)")
            isSaving = false
        }
    }

    private func clearCredentials() {
        do {
            try dependenciesStore.clearCredentials()
            username = ""
            apiKey = ""
            status = .success("Данные удалены")
        } catch {
            status = .error("Не удалось удалить: \(error.localizedDescription)")
        }
    }

    private func loadCacheSettings() {
        Task {
            let limit = await ImageDiskCache.shared.limitInMegabytes()
            let usageBytes = await ImageDiskCache.shared.currentUsageBytes()
            await MainActor.run {
                cacheLimitMB = Double(limit)
                appliedCacheLimitMB = Double(limit)
                cacheUsageMB = bytesToMB(usageBytes)
            }
        }
    }

    private func applyCacheLimit() {
        guard Int(cacheLimitMB) != Int(appliedCacheLimitMB) else { return }
        isUpdatingCacheLimit = true
        Task {
            await ImageDiskCache.shared.updateLimit(megabytes: Int(cacheLimitMB))
            let usageBytes = await ImageDiskCache.shared.currentUsageBytes()
            await MainActor.run {
                appliedCacheLimitMB = cacheLimitMB
                cacheUsageMB = bytesToMB(usageBytes)
                isUpdatingCacheLimit = false
                status = .success("Лимит кеша обновлён")
            }
        }
    }

    private func clearCacheStorage() {
        isClearingCache = true
        Task {
            await ImageDiskCache.shared.clear()
            await MainActor.run {
                cacheUsageMB = 0
                isClearingCache = false
                status = .success("Кеш изображений очищен")
            }
        }
    }

    private func bytesToMB(_ bytes: Int) -> Double {
        Double(bytes) / 1_048_576.0
    }

    private func formattedMB(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    // MARK: - Sections

    private var credentialsSection: some View {
        SettingsCard(
            header: {
                Label("Danbooru Credentials", systemImage: "key.fill")
            }, minHeight: 260
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Username").settingsLabel()
                        TextField("Username", text: $username)
                            .themedInputField(
                                systemImage: "person.fill",
                                trailingSystemImage: username.isEmpty ? nil : "xmark.circle.fill",
                                onTrailingTap: username.isEmpty ? nil : { username = "" }
                            )
                            .textContentType(.username)
                            .disableAutocorrection(true)
                            .frame(maxWidth: 280)
                    }
                    GridRow {
                        Text("API Key").settingsLabel()
                        SecureField("API Key", text: $apiKey)
                            .themedInputField(
                                systemImage: "key.fill",
                                trailingSystemImage: apiKey.isEmpty ? nil : "xmark.circle.fill",
                                onTrailingTap: apiKey.isEmpty ? nil : { apiKey = "" }
                            )
                            .textContentType(.password)
                            .disableAutocorrection(true)
                            .frame(maxWidth: 280)
                    }
                }

                Text(
                    "Данные хранятся в системном Keychain и используются для избранного, голосований и комментариев."
                )
                .font(.footnote)
                .foregroundStyle(Theme.ColorPalette.textMuted)

                if let profile = dependenciesStore.profile {
                    AccountSummaryView(profile: profile)
                } else if let error = dependenciesStore.authenticationError {
                    StatusBanner(
                        text: "Ошибка проверки: \(error)",
                        symbol: "exclamationmark.triangle.fill",
                        tint: .red
                    )
                }

                HStack(spacing: 12) {
                    Button(role: .destructive, action: clearCredentials) {
                        Label("Очистить", systemImage: "trash")
                    }
                    .buttonStyle(Theme.GlassButtonStyle(kind: .destructive))
                    .disabled(!(dependenciesStore.credentials.hasCredentials))

                    Button(action: saveCredentials) {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Сохранить", systemImage: "checkmark.circle.fill")
                        }
                    }
                    .buttonStyle(Theme.GlassButtonStyle(kind: .primary))
                    .disabled(isSaving)
                }
            }
        }
    }

    private var cacheSection: some View {
        SettingsCard(header: {
            Label("Кеш изображений", systemImage: "externaldrive.fill.badge.timemachine")
        }) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Максимальный размер кеша")
                    .font(.subheadline.weight(.semibold))

                Slider(value: $cacheLimitMB, in: 128...1024, step: 64)
                    .tint(Theme.ColorPalette.accent)

                HStack {
                    Text("Текущий лимит: \(Int(cacheLimitMB)) МБ")
                    Spacer()
                    Text("Используется: \(formattedMB(cacheUsageMB)) МБ")
                        .foregroundStyle(Theme.ColorPalette.textMuted)
                }

                HStack(spacing: 12) {
                    Button(action: applyCacheLimit) {
                        if isUpdatingCacheLimit {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Применить", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(Theme.GlassButtonStyle(kind: .primary))
                    .disabled(isUpdatingCacheLimit || Int(cacheLimitMB) == Int(appliedCacheLimitMB))

                    Button(role: .destructive, action: clearCacheStorage) {
                        if isClearingCache {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Очистить", systemImage: "trash")
                        }
                    }
                    .buttonStyle(Theme.GlassButtonStyle(kind: .destructive))
                    .disabled(isClearingCache || cacheUsageMB <= 0.1)
                }
            }
        }
    }

    private var generalSection: some View {
        SettingsCard(header: {
            Label("Общие настройки", systemImage: "slider.horizontal.3")
        }) {
            VStack(alignment: .leading, spacing: 12) {
                ToggleRow(
                    title: "Обновлять список постов при запуске",
                    subtitle: "Автоматически загружает свежие посты при старте приложения.",
                    systemImage: "arrow.clockwise",
                    isOn: $autoRefreshOnLaunch
                )
                Divider().opacity(0.1)
                ToggleRow(
                    title: "Показывать подсказки горячих клавиш",
                    subtitle: "Отображает команды в интерфейсе и тултипах.",
                    systemImage: "command",
                    isOn: $showKeyboardHints
                )
                Divider().opacity(0.1)
                ToggleRow(
                    title: "Размывать контент NSFW по умолчанию",
                    subtitle: "Применяет блюр к чувствительным постам и деталям.",
                    systemImage: "eye.slash",
                    isOn: $blurSensitiveDefault
                )
            }
        }
    }

    private var resourcesSection: some View {
        SettingsCard(
            header: {
                Label("Дополнительно", systemImage: "info.circle")
            }, minHeight: 240
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ссылки и инструменты")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ColorPalette.textSecondary)
                VStack(alignment: .leading, spacing: 10) {
                    LinkRow(
                        title: "Документация API",
                        subtitle: "danbooru.donmai.us",
                        systemImage: "doc.text",
                        destination: URL(string: "https://danbooru.donmai.us/wiki_pages/help:api")!
                    )
                    ActionRow(
                        title: "Открыть Keychain",
                        subtitle: "Управление сохранёнными ключами доступа",
                        systemImage: "key"
                    ) {
                        openKeychainApp()
                    }
                    LinkRow(
                        title: "Проект на GitHub",
                        subtitle: "github.com/MikoMikocchi/Macbooru",
                        systemImage: "link",
                        destination: URL(string: "https://github.com/MikoMikocchi/Macbooru")!
                    )
                }
            }
        }
    }

    private var statusSection: some View {
        SettingsCard(
            header: {
                Label("Состояние", systemImage: "bell")
            }, minHeight: 220
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if let status {
                    statusView(status)
                } else if let authError = dependenciesStore.authenticationError {
                    StatusBanner(
                        text: authError,
                        symbol: "exclamationmark.triangle.fill",
                        tint: .red
                    )
                } else {
                    StatusBanner(
                        text: "Все системы в норме",
                        symbol: "checkmark.circle.fill",
                        tint: .green
                    )
                }
            }
        }
    }

    private func statusSymbol(for status: StatusMessage) -> String {
        switch status {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private func statusView(_ status: StatusMessage) -> some View {
        StatusBanner(
            text: status.text,
            symbol: statusSymbol(for: status),
            tint: status.color
        )
    }

    private func openKeychainApp() {
        #if os(macOS)
            let keychainURL = URL(fileURLWithPath: "/Applications/Utilities/Keychain Access.app")
            NSWorkspace.shared.open(keychainURL)
        #endif
    }
}

// MARK: - Subviews & Styles

private struct StatusBanner: View {
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(tint)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // Клипуем материал формой, чтобы не было "квадратной" подложки
            tint.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

private struct ToggleRow: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.ColorPalette.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.ColorPalette.textMuted)
                    }
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.ColorPalette.accent))
        .padding(.vertical, 4)
        .accessibilityHint(Text(subtitle ?? ""))
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.ColorPalette.controlBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.ColorPalette.glassBorder.opacity(0.6), lineWidth: 1)
            )
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ColorPalette.accent)
            )
    }
}

private struct RowBase<Accessory: View>: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var tint: Color
    let accessory: () -> Accessory
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.ColorPalette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.ColorPalette.textMuted)
                }
            }
            Spacer(minLength: 0)
            accessory()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Theme.ColorPalette.controlBackground.opacity(hovering ? 1.0 : 0.85),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Theme.ColorPalette.glassBorder.opacity(hovering ? 0.7 : 0.45), lineWidth: 1)
        )
        .scaleEffect(hovering ? 1.02 : 1.0)
        .shadow(
            color: Theme.ColorPalette.shadowSoft.opacity(0.45), radius: hovering ? 9 : 6, x: 0,
            y: hovering ? 4 : 2
        )
        .animation(Theme.Animations.interactive(), value: hovering)
        .onHover { value in
            withAnimation(Theme.Animations.hover()) {
                hovering = value
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(subtitle ?? ""))
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            )
    }
}

private struct LinkRow: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    let destination: URL
    var tint: Color = Theme.ColorPalette.accent

    var body: some View {
        Link(destination: destination) {
            RowBase(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ColorPalette.textMuted)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ActionRow: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var tint: Color = Theme.ColorPalette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RowBase(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ColorPalette.textMuted)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AccountSummaryView: View {
    let profile: UserProfile

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                if let level = profile.level {
                    Text(level)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let created = profile.createdAt {
                    Text(
                        "Зарегистрирован: \(created.formatted(date: .abbreviated, time: .omitted))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

private struct SettingsCard<Header: View, Content: View>: View {
    @Environment(\.sizeCategory) private var sizeCategory
    var header: () -> Header
    var content: () -> Content
    var minHeight: CGFloat

    init(
        header: @escaping () -> Header, minHeight: CGFloat = 220,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.header = header
        self.content = content
        self.minHeight = minHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header()
                .font(.title3.weight(.semibold))
            content()
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .glassCard(cornerRadius: 20, hoverElevates: false)
    }

    private var horizontalPadding: CGFloat {
        sizeCategory.isAccessibilityCategory
            ? Theme.Constants.cardPadding + 6 : Theme.Constants.cardPadding
    }

    private var verticalPadding: CGFloat {
        max(16, horizontalPadding - 6)
    }
}

extension Text {
    fileprivate func settingsLabel() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .trailing)
            .foregroundStyle(.secondary)
            .font(.headline)
    }
}
