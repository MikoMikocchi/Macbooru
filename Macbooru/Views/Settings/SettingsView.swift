import SwiftUI

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
        Form {
            Section("Danbooru Credentials") {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .disableAutocorrection(true)
                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)
                    .disableAutocorrection(true)

                Text("Данные хранятся в системном Keychain и используются для избранного/голосований/комментариев.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button(role: .destructive) {
                        clearCredentials()
                    } label: {
                        Label("Очистить", systemImage: "trash")
                    }
                    .disabled(!(dependenciesStore.credentials.hasCredentials))

                    Spacer()

                    Button(action: saveCredentials) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Сохранить", systemImage: "checkmark")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Section("Кеш изображений") {
                VStack(alignment: .leading, spacing: 8) {
                    Stepper(value: $cacheLimitMB, in: 64...1024, step: 64) {
                        Text("Максимальный размер: \(Int(cacheLimitMB)) МБ")
                    }
                    HStack {
                        Button {
                            applyCacheLimit()
                        } label: {
                            if isUpdatingCacheLimit {
                                ProgressView()
                            } else {
                                Label("Применить", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(isUpdatingCacheLimit || Int(cacheLimitMB) == Int(appliedCacheLimitMB))

                        Button(role: .destructive) {
                            clearCacheStorage()
                        } label: {
                            if isClearingCache {
                                ProgressView()
                            } else {
                                Label("Очистить", systemImage: "trash")
                            }
                        }
                        .disabled(isClearingCache || cacheUsageMB <= 0.1)
                    }
                    Text("Текущий объём: \(formattedMB(cacheUsageMB)) МБ")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let status {
                Text(status.text)
                    .font(.subheadline)
                    .foregroundStyle(status.color)
                    .padding(.vertical, 4)
            }
        }
        .padding()
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
            status = .success(dependenciesStore.hasCredentials ? "Данные сохранены" : "Данные очищены")
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
}
