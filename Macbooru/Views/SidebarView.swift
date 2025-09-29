import SwiftUI

struct SidebarView: View {
    @ObservedObject var state: SearchState
    var onSearch: (() -> Void)?

    var body: some View {
        Form {
            Section("Search") {
                TextField("tags", text: $state.tags)
                    .textFieldStyle(.roundedBorder)
                Picker("Rating", selection: $state.rating) {
                    ForEach(Rating.allCases) { r in Text(r.display).tag(r) }
                }
                .pickerStyle(.segmented)
                Picker("Tile size", selection: $state.tileSize) {
                    ForEach(TileSize.allCases) { t in Text(t.title).tag(t) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Button("Search") { state.resetForNewSearch(); onSearch?() }
                        .keyboardShortcut(.return, modifiers: [])
                    Spacer()
                }
            }
        }
        .padding()
    }
}
