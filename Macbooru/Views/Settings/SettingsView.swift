import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dependenciesStore: AppDependenciesStore
    @State private var username: String = ""
    @State private var apiKey: String = ""
    @State private var status: StatusMessage? = nil
    @State private var isSaving = false

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

            if let status {
                Text(status.text)
                    .font(.subheadline)
                    .foregroundStyle(status.color)
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .onAppear(perform: loadFromStore)
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
}
