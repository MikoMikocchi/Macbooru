import SwiftUI

struct SidebarView: View {
    @ObservedObject var state: SearchState
    var onSearch: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search").font(.headline)
                TextField("Enter tags…", text: $state.tags)
                    .textFieldStyle(.roundedBorder)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rating").font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Rating", selection: $state.rating) {
                        ForEach(Rating.allCases) { r in Text(r.display).tag(r) }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tile size").font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Tile size", selection: $state.tileSize) {
                        ForEach(TileSize.allCases) { t in Text(t.title).tag(t) }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .labelsHidden()
                }
                Button("Search") { state.resetForNewSearch(); onSearch?() }
                    .keyboardShortcut(.return, modifiers: [])
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }
}
