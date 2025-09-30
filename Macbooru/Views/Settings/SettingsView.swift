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

    private let cardColumns = [
        GridItem(.flexible(minimum: 320), spacing: 24),
        GridItem(.flexible(minimum: 320), spacing: 24),
    ]

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
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.username)
                            .disableAutocorrection(true)
                            .frame(maxWidth: 280)
                    }
                    GridRow {
                        Text("API Key").settingsLabel()
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .disableAutocorrection(true)
                            .frame(maxWidth: 280)
                    }
                }

                Text(
                    "Данные хранятся в системном Keychain и используются для избранного/голосований/комментариев."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

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
                    .buttonStyle(.bordered)
                    .disabled(!(dependenciesStore.credentials.hasCredentials))

                    Button(action: saveCredentials) {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Сохранить", systemImage: "checkmark.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
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

                HStack {
                    Text("Текущий лимит: \(Int(cacheLimitMB)) МБ")
                    Spacer()
                    Text("Используется: \(formattedMB(cacheUsageMB)) МБ")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button(action: applyCacheLimit) {
                        if isUpdatingCacheLimit {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Применить", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUpdatingCacheLimit || Int(cacheLimitMB) == Int(appliedCacheLimitMB))

                    Button(role: .destructive, action: clearCacheStorage) {
                        if isClearingCache {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Очистить", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isClearingCache || cacheUsageMB <= 0.1)
                }
            }
        }
    }

    private var generalSection: some View {
        SettingsCard(header: {
            Label("Общие настройки", systemImage: "slider.horizontal.3")
        }) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $autoRefreshOnLaunch) {
                    Label("Обновлять список постов при запуске", systemImage: "arrow.clockwise")
                }
                Toggle(isOn: $showKeyboardHints) {
                    Label("Показывать подсказки горячих клавиш", systemImage: "command")
                }
                Toggle(isOn: $blurSensitiveDefault) {
                    Label("Размывать контент NSFW по умолчанию", systemImage: "eye.slash")
                }
            }
        }
    }

    private var resourcesSection: some View {
        SettingsCard(
            header: {
                Label("Дополнительно", systemImage: "info.circle")
            }, minHeight: 220
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ссылки и инструменты")
                    .font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 12) {
                    Link(
                        destination: URL(string: "https://danbooru.donmai.us/wiki_pages/help:api")!
                    ) {
                        Label("Документация API", systemImage: "doc.text")
                    }
                    Button {
                        openKeychainApp()
                    } label: {
                        Label("Открыть Keychain", systemImage: "key")
                    }
                    Link(destination: URL(string: "https://github.com/MikoMikocchi/Macbooru")!) {
                        Label("Проект на GitHub", systemImage: "link")
                    }
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
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: symbol)
                .foregroundColor(tint)
            Text(text)
                .font(.subheadline)
                .foregroundColor(tint)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
        )
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
        .padding(22)
        .background(
            // Лёгкая полупрозрачная подложка для лучшей читаемости на вибранси-фоне окна
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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
