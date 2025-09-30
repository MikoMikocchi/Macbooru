import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct SidebarView: View {
    @ObservedObject var state: SearchState
    var onSearch: (() -> Void)?
    private let tagsRepo = TagsRepositoryImpl(client: DanbooruClient())
    @State private var tagQuery: String = ""
    @State private var suggestions: [Tag] = []
    @State private var isLoadingSuggest = false
    // Дебаунс и фокус
    @State private var debounceTask: Task<Void, Never>? = nil
    @FocusState private var isSearchFocused: Bool
    // Клавиатура/хайлайт
    @State private var selectedIndex: Int = 0
    // Управление поповером через вычисляемый биндинг: открыт только когда есть подсказки

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
                        .onChange(of: state.tags) { newValue in
                            scheduleAutocomplete(for: newValue)
                        }
                        .onSubmit {
                            // Enter = выполнить поиск по текущему вводу
                            suggestions.removeAll()
                            state.resetForNewSearch()
                            onSearch?()
                        }
                        .focused($isSearchFocused)
                        .onChange(of: isSearchFocused) { newFocused in
                            if !newFocused { suggestions.removeAll() }
                        }
                        // Закрытие по Esc
                        #if os(macOS)
                            .onExitCommand { suggestions.removeAll() }
                            // Навигация стрелками и выбор Enter (macOS 14+)
                            .onKeyPress(.upArrow) {
                                moveSelection(1)
                                return .handled
                            }
                            .onKeyPress(.downArrow) {
                                if suggestions.isEmpty {
                                    let token = lastToken(in: state.tags)
                                    if token.count >= 2 {
                                        Task { await loadSuggestions(prefix: token) }
                                    }
                                    selectedIndex = 0
                                    return .handled
                                } else {
                                    moveSelection(1)
                                    return .handled
                                }
                            }
                            // Enter = принять выделенную подсказку (если она есть) и добавить пробел; иначе — отдать .onSubmit()
                            .onKeyPress(.return) {
                                if !suggestions.isEmpty, suggestions.indices.contains(selectedIndex)
                                {
                                    insertTag(suggestions[selectedIndex].name, trailingSpace: true)
                                    return .handled
                                }
                                return .ignored
                            }
                            .onKeyPress(.upArrow) {
                                moveSelection(-1)
                                return .handled
                            }
                            // Tab = принять подсказку
                            .onKeyPress(.tab) {
                                if !suggestions.isEmpty, suggestions.indices.contains(selectedIndex)
                                {
                                    insertTag(suggestions[selectedIndex].name)
                                    return .handled
                                }
                                return .ignored
                            }
                        #endif
                        // Размещение подсказок: на macOS используем popover, чтобы список не перекрывал поле и не «улетал»
                        #if os(macOS)
                            .popover(
                                isPresented: Binding(
                                    get: { !suggestions.isEmpty },
                                    set: { shown in if !shown { suggestions.removeAll() } }
                                ),
                                attachmentAnchor: .point(.bottom),
                                arrowEdge: .top
                            ) {
                                SuggestList(
                                    items: suggestions,
                                    highlight: tagQuery,
                                    selectedIndex: $selectedIndex,
                                    inPopover: true,
                                    onSelect: { insertTag($0.name) }
                                )
                                .id(suggestions.count)
                                .frame(minWidth: 260)
                                .frame(maxHeight: 260)
                                .padding(Edge.Set.top, 6)  // небольшой отступ, чтобы стрелка поповера не «накрывала» первый элемент
                                .padding(Edge.Set.horizontal, 4)
                            }
                        #else
                            .overlay(alignment: .bottomLeading) {
                                if !suggestions.isEmpty {
                                    SuggestList(
                                        items: suggestions,
                                        highlight: tagQuery,
                                        selectedIndex: $selectedIndex,
                                        inPopover: false,
                                        onSelect: { insertTag($0.name) }
                                    )
                                    .offset(y: 8)
                                    .zIndex(1000)
                                    .shadow(radius: 8)
                                }
                            }
                        #endif
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

extension SidebarView {
    fileprivate func scheduleAutocomplete(for input: String) {
        let token = lastToken(in: input)
        tagQuery = token
        guard token.count >= 2 else {
            suggestions = []
            return
        }
        // Дебаунс: отменяем предыдущую задачу и ждём 250 мс
        debounceTask?.cancel()
        debounceTask = Task { [token] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await loadSuggestions(prefix: token)
        }
    }

    fileprivate func lastToken(in input: String) -> String {
        // Если строка оканчивается пробелом, значит пользователь завершил токен — не подсказываем
        if input.last == " " { return "" }
        return input.split(separator: " ").last.map(String.init) ?? input
    }

    fileprivate func insertTag(_ name: String, trailingSpace: Bool = false) {
        var parts = state.tags.split(separator: " ").map(String.init)
        if parts.isEmpty {
            state.tags = trailingSpace ? (name + " ") : name
        } else {
            parts.removeLast()
            parts.append(name)
            var joined = parts.joined(separator: " ")
            if trailingSpace { joined.append(" ") }
            state.tags = joined
        }
        suggestions = []
        selectedIndex = 0
        isSearchFocused = true
    }

    @MainActor
    fileprivate func loadSuggestions(prefix: String) async {
        guard !isLoadingSuggest else { return }
        isLoadingSuggest = true
        defer { isLoadingSuggest = false }
        do {
            let tags = try await tagsRepo.autocomplete(prefix: prefix, limit: 12)
            suggestions = tags
            selectedIndex = 0
        } catch {
            suggestions = []
        }
    }

    // Перемещение выделения
    fileprivate func moveSelection(_ delta: Int) {
        guard !suggestions.isEmpty else { return }
        let newIndex = max(0, min(suggestions.count - 1, selectedIndex + delta))
        if newIndex != selectedIndex { selectedIndex = newIndex }
    }
}

// Compact suggest list UI
private struct SuggestList: View {
    let items: [Tag]
    var highlight: String
    @Binding var selectedIndex: Int
    var inPopover: Bool
    var onSelect: (Tag) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.indices), id: \.self) { idx in
                        let tag = items[idx]
                        Button(action: { onSelect(tag) }) {
                            HStack(spacing: 8) {
                                highlightedText(tag.displayName, match: highlight)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(tag.kind).foregroundStyle(.secondary).font(.caption2)
                                if let c = tag.postCount {
                                    Text("\(c)").foregroundStyle(.secondary).font(.caption2)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                idx == selectedIndex ? Color.accentColor.opacity(0.12) : Color.clear
                            )
                            .id(idx)
                        }
                        .buttonStyle(.plain)
                        if idx < items.count - 1 { Divider() }
                    }
                }
                .onChange(of: selectedIndex) { newValue in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        // Оформление: в popover фон системный, без наших скруглений, чтобы углы не перекрывали контент
        .modifier(SuggestListChrome(inPopover: inPopover))
    }

    // Подсветка совпадений
    private func highlightedText(_ text: String, match: String) -> Text {
        guard !match.isEmpty else { return Text(text) }
        var attr = AttributedString(text)
        let lower = text.lowercased()
        let query = match.lowercased()
        if let r = lower.range(of: query),
            let start = AttributedString.Index(r.lowerBound, within: attr),
            let end = AttributedString.Index(r.upperBound, within: attr)
        {
            let range = start..<end
            attr[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return Text(attr)
    }
}

// Офорление для списка подсказок, чтобы единообразно переключать вид для popover/overlay
private struct SuggestListChrome: ViewModifier {
    var inPopover: Bool
    func body(content: Content) -> some View {
        #if os(macOS)
            if inPopover {
                content  // системный поповер сам рисует фон и скругления
            } else {
                content
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quinary, lineWidth: 1))
            }
        #else
            content
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quinary, lineWidth: 1))
        #endif
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
