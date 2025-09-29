import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct SidebarView: View {
    @ObservedObject var state: SearchState
    var onSearch: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Фон-материал тянем под титлбар, чтобы не было «ступеньки»
            #if os(macOS)
                VisualEffectView(
                    material: .sidebar, blendingMode: .withinWindow,
                    state: .followsWindowActiveState
                )
                .ignoresSafeArea(.container, edges: [.top])
            #else
                Color(.systemBackground)
                    .ignoresSafeArea(.container, edges: [.top])
            #endif

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
                    Toggle(isOn: $state.blurSensitive) {
                        Label("Blur NSFW (Q/E)", systemImage: "eye.slash")
                    }
                    .toggleStyle(.switch)
                    Button("Search") {
                        state.resetForNewSearch()
                        onSearch?()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#if os(macOS)
    // Нативный фон через NSVisualEffectView (material: .sidebar)
    private struct VisualEffectView: NSViewRepresentable {
        var material: NSVisualEffectView.Material
        var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
        var state: NSVisualEffectView.State = .active

        func makeNSView(context: Context) -> NSVisualEffectView {
            let v = NSVisualEffectView()
            v.material = material
            v.blendingMode = blendingMode
            v.state = state
            v.isEmphasized = true
            v.translatesAutoresizingMaskIntoConstraints = false
            return v
        }

        func updateNSView(_ v: NSVisualEffectView, context: Context) {
            v.material = material
            v.blendingMode = blendingMode
            v.state = state
        }
    }
#endif
