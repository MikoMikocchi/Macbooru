import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct SidebarView: View {
    @ObservedObject var state: SearchState
    @Environment(\.appDependencies) private var dependencies
    @AppStorage("settings.showKeyboardHints") private var showKeyboardHints: Bool = true
    private let savedStore = SavedSearchStore()
    private let recentStore = RecentSearchStore()
    @State private var tagQuery: String = ""
    @State private var suggestions: [Tag] = []
    @State private var isLoadingSuggest = false
    // Дебаунс и фокус
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var suggestionsTask: Task<Void, Never>? = nil
    @State private var suggestionsRequestID: Int = 0
    @FocusState private var isSearchFocused: Bool
    // Клавиатура/хайлайт
    @State private var selectedIndex: Int = 0
    // Управление поповером через вычисляемый биндинг: открыт только когда есть подсказки
    @State private var saved: [SavedSearch] = []
    @AppStorage("sidebar.savedExpanded") private var isSavedExpanded: Bool = false
    @State private var recent: [RecentSearch] = []

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
                VStack(alignment: .leading, spacing: 16) {
                    // Современный заголовок
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.blue.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Search")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            Text("Find posts with tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    // Поле поиска с современным дизайном
                    VStack(spacing: 12) {
                        TextField("Enter tags…", text: $state.tags)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .overlay(alignment: .trailing) {
                                if !state.tags.isEmpty {
                                    Button {
                                        clearSearch()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 12)
                                }
                            }

                        // Кнопки действий (переносим Search сюда)
                        HStack(spacing: 8) {
                            Button {
                                // Выполнить поиск
                                suggestions.removeAll()
                                state.resetForNewSearch()
                                let q = state.tags.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !q.isEmpty {
                                    recentStore.addOrTouch(
                                        query: q, rating: state.rating, sort: state.sort)
                                    refreshRecent()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Search")
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.18), in: Capsule())
                                .foregroundStyle(.blue)
                            }
                            .keyboardShortcut(.return, modifiers: [])
                            .buttonStyle(.plain)
                            Button {
                                saveCurrentSearch()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Save")
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.1), in: Capsule())
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)

                            Button {
                                clearSearch()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Clear")
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.red.opacity(0.1), in: Capsule())
                                .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                        #if os(macOS)
                            if showKeyboardHints {
                                Group {
                                    if #available(macOS 14.0, *) {
                                        Text("Enter: search • ↑/↓: navigate • Tab/Enter: apply suggestion")
                                    } else {
                                        Text("Enter: search")
                                    }
                                }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        #endif
                    }
                    // Делаем команды доступными через focusedSceneValue
                    .focusedSceneValue(
                        \.searchActions,
                        SearchActions(
                            focusSearch: {
                                #if os(macOS)
                                    isSearchFocused = true
                                #endif
                            },
                            setPageSize15: {
                                guard state.pageSize != 15 else { return }
                                state.pageSize = 15
                                state.resetForNewSearch()
                            },
                            setPageSize30: {
                                guard state.pageSize != 30 else { return }
                                state.pageSize = 30
                                state.resetForNewSearch()
                            },
                            setPageSize60: {
                                guard state.pageSize != 60 else { return }
                                state.pageSize = 60
                                state.resetForNewSearch()
                            }
                        )
                    )

                    .onChangeCompat(of: state.tags) { newValue in
                        scheduleAutocomplete(for: newValue)
                    }
                    .onSubmit {
                        // Enter = выполнить поиск по текущему вводу
                        suggestions.removeAll()
                        state.resetForNewSearch()
                        let q = state.tags.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !q.isEmpty {
                            recentStore.addOrTouch(query: q, rating: state.rating, sort: state.sort)
                            refreshRecent()
                        }
                    }
                    .focused($isSearchFocused)
                    .onChangeCompat(of: isSearchFocused) { newFocused in
                        if !newFocused { suggestions.removeAll() }
                    }
                    // Закрытие по Esc
                    #if os(macOS)
                        .onExitCommand { suggestions.removeAll() }
                        .modifier(
                            SearchFieldKeyPressModifier(
                                suggestions: $suggestions,
                                selectedIndex: $selectedIndex,
                                currentTags: { state.tags },
                                lastToken: { input in lastToken(in: input) },
                                loadSuggestions: { token in
                                    startSuggestionsRequest(prefix: token)
                                },
                                insertTag: { name, trailingSpace in
                                    insertTag(name, trailingSpace: trailingSpace)
                                },
                                moveSelection: { delta in moveSelection(delta) }
                            )
                        )
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
                    // Современная секция сохраненных поисков
                    if !saved.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.orange.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.orange)
                                }

                                Text("Saved Searches")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSavedExpanded.toggle()
                                    }
                                } label: {
                                    Image(
                                        systemName: isSavedExpanded ? "chevron.up" : "chevron.down"
                                    )
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees(isSavedExpanded ? 180 : 0))
                                    .animation(.easeInOut(duration: 0.2), value: isSavedExpanded)
                                }
                                .buttonStyle(.plain)
                            }

                            ChipsFlowLayout(spacing: 8, rowSpacing: 8) {
                                ForEach(saved) { item in
                                    ModernSavedChip(item: item) {
                                        performSavedSearch(item)
                                    }
                                    .contextMenu {
                                        Button(item.pinned ? "Unpin" : "Pin") {
                                            togglePin(item)
                                        }
                                        Button("Delete", role: .destructive) {
                                            deleteSaved(item)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(maxHeight: isSavedExpanded ? .infinity : 100, alignment: .top)
                            .clipped()
                            .overlay(alignment: .bottom) {
                                if !isSavedExpanded && saved.count > 3 {
                                    LinearGradient(
                                        colors: [
                                            Color.clear,
                                            Color("PrimaryBackground").opacity(0.8),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 20)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    // Современная секция недавних поисков
                    if !recent.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.purple.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.purple)
                                }

                                Text("Recent Searches")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        recentStore.clear()
                                        refreshRecent()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }

                            ChipsFlowLayout(spacing: 8, rowSpacing: 8) {
                                ForEach(recent) { item in
                                    ModernRecentChip(item: item) {
                                        performRecentSearch(item)
                                    }
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            recentStore.remove(id: item.id)
                                            refreshRecent()
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(maxHeight: 100)
                            .clipped()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    // Sort mode (wrap chips)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill").foregroundStyle(
                                .secondary)
                            Text("Sort").font(.subheadline).fontWeight(.semibold).foregroundStyle(
                                .secondary)
                        }
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        ChipsFlowLayout(spacing: 8, rowSpacing: 8) {
                            ForEach(SortMode.allCases) { m in
                                Button {
                                    if state.sort != m {
                                        state.sort = m
                                        state.resetForNewSearch()
                                    }
                                } label: {
                                    Text(m.label)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(
                                                state.sort == m
                                                    ? Color.accentColor.opacity(0.25)
                                                    : Color.secondary.opacity(0.15)
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "tray.full.fill").foregroundStyle(.secondary)
                            Text("Pool ID").font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(
                                    .secondary)
                        }
                        TextField("pool:12345", text: $state.poolID)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                state.resetForNewSearch()
                            }
                            .onChangeCompat(of: state.poolID) { _ in
                                // не триггерим сразу поиск, чтобы не дёргать API при наборе — пользователь нажмёт Enter/кнопку
                            }
                    }
                    // Убрали переключатель Layout — используем только Grid
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill").foregroundStyle(.secondary)
                            Text("Rating").font(.subheadline).fontWeight(.semibold).foregroundStyle(
                                .secondary)
                        }
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
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.3x3.fill").foregroundStyle(.secondary)
                            Text("Tile size").font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "number.circle.fill").foregroundStyle(.secondary)
                            Text("Page size").font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Picker("Page size", selection: $state.pageSize) {
                            Text("15").tag(15)
                            Text("30").tag(30)
                            Text("60").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .labelsHidden()
                        .onChangeCompat(of: state.pageSize) { _ in
                            state.resetForNewSearch()
                        }
                    }
                    // Перенесено в Settings: Infinite Scroll и Low Performance
                    Toggle(isOn: $state.blurSensitive) {
                        Label("Blur NSFW (Q/E)", systemImage: "eye.slash")
                    }
                    .toggleStyle(.switch)
                    // Кнопку Search снизу убрали — она перенесена наверх к полю ввода
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshSaved()
            refreshRecent()
        }
        .onDisappear {
            debounceTask?.cancel()
            suggestionsTask?.cancel()
        }
        .focusedSceneValue(
            \.searchActions,
            SearchActions(
                focusSearch: {
                    #if os(macOS)
                        isSearchFocused = true
                    #endif
                },
                setPageSize15: {
                    guard state.pageSize != 15 else { return }
                    state.pageSize = 15
                    state.resetForNewSearch()
                },
                setPageSize30: {
                    guard state.pageSize != 30 else { return }
                    state.pageSize = 30
                    state.resetForNewSearch()
                },
                setPageSize60: {
                    guard state.pageSize != 60 else { return }
                    state.pageSize = 60
                    state.resetForNewSearch()
                }
            ))
    }
}

extension SidebarView {
    fileprivate func clearSearch() {
        suggestions.removeAll()
        state.tags = ""
        state.rating = .any
        state.sort = .recent
        state.resetForNewSearch()
        // Вернём фокус в поле ввода для продолжения работы
        #if os(macOS)
            isSearchFocused = true
        #endif
    }
    fileprivate func scheduleAutocomplete(for input: String) {
        let token = lastToken(in: input)
        tagQuery = token
        guard token.count >= 2 else {
            suggestions = []
            isLoadingSuggest = false
            suggestionsTask?.cancel()
            return
        }
        // Дебаунс: отменяем предыдущую задачу и ждём 250 мс
        debounceTask?.cancel()
        debounceTask = Task { [token] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                startSuggestionsRequest(prefix: token)
            }
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
    fileprivate func startSuggestionsRequest(prefix: String) {
        suggestionsTask?.cancel()
        suggestionsRequestID &+= 1
        let requestID = suggestionsRequestID
        isLoadingSuggest = true

        let autocomplete = dependencies.autocompleteTags
        suggestionsTask = Task {
            do {
                let tags = try await autocomplete.execute(prefix: prefix, limit: 12)
                await MainActor.run {
                    guard requestID == suggestionsRequestID else { return }
                    suggestions = tags
                    selectedIndex = 0
                    isLoadingSuggest = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    if requestID == suggestionsRequestID {
                        isLoadingSuggest = false
                    }
                }
            } catch {
                await MainActor.run {
                    guard requestID == suggestionsRequestID else { return }
                    suggestions = []
                    isLoadingSuggest = false
                }
            }
        }
    }

    // Перемещение выделения
    fileprivate func moveSelection(_ delta: Int) {
        guard !suggestions.isEmpty else { return }
        let newIndex = max(0, min(suggestions.count - 1, selectedIndex + delta))
        if newIndex != selectedIndex { selectedIndex = newIndex }
    }
}

#if os(macOS)
    private struct SearchFieldKeyPressModifier: ViewModifier {
        @Binding var suggestions: [Tag]
        @Binding var selectedIndex: Int
        let currentTags: () -> String
        let lastToken: (String) -> String
        let loadSuggestions: (String) -> Void
        let insertTag: (String, Bool) -> Void
        let moveSelection: (Int) -> Void

        @ViewBuilder
        func body(content: Content) -> some View {
            if #available(macOS 14.0, *) {
                content
                    .onKeyPress(.downArrow) {
                        if suggestions.isEmpty {
                            let token = lastToken(currentTags())
                            if token.count >= 2 {
                                loadSuggestions(token)
                            }
                            selectedIndex = 0
                            return .handled
                        } else {
                            moveSelection(1)
                            return .handled
                        }
                    }
                    .onKeyPress(.return) {
                        if !suggestions.isEmpty, suggestions.indices.contains(selectedIndex) {
                            insertTag(suggestions[selectedIndex].name, true)
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.upArrow) {
                        moveSelection(-1)
                        return .handled
                    }
                    .onKeyPress(.tab) {
                        if !suggestions.isEmpty, suggestions.indices.contains(selectedIndex) {
                            insertTag(suggestions[selectedIndex].name, false)
                            return .handled
                        }
                        return .ignored
                    }
            } else {
                content
            }
        }
    }
#endif

// Compact suggest list UI
// Современные компоненты чипов
private struct ModernSavedChip: View {
    let item: SavedSearch
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.orange.opacity(hovering ? 0.12 : 0.08))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(hovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.hovering = hovering
            }
        }
        .help(label)
    }

    private var label: String {
        if item.rating == .any { return item.query }
        return "\(item.rating.display) · \(item.query)"
    }
}

private struct ModernRecentChip: View {
    let item: RecentSearch
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.purple)
                Text(label)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.purple.opacity(hovering ? 0.12 : 0.08))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(hovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.hovering = hovering
            }
        }
        .help(label)
    }

    private var label: String {
        var parts: [String] = []
        if item.rating != .any { parts.append(item.rating.display) }
        if let s = item.sort { parts.append(s.label) }
        parts.append(item.query)
        return parts.joined(separator: " · ")
    }
}

// Saved logic
extension SidebarView {
    fileprivate func refreshSaved() {
        saved = savedStore.list()
    }
    fileprivate func saveCurrentSearch() {
        let query = state.tags.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        savedStore.addOrUpdate(query: query, rating: state.rating, sort: state.sort)
        refreshSaved()
    }
    fileprivate func performSavedSearch(_ item: SavedSearch) {
        state.tags = item.query
        state.rating = item.rating
        if let s = item.sort { state.sort = s }
        state.resetForNewSearch()
        savedStore.touch(id: item.id)
        refreshSaved()
    }
    fileprivate func togglePin(_ item: SavedSearch) {
        savedStore.togglePin(id: item.id)
        refreshSaved()
    }
    fileprivate func deleteSaved(_ item: SavedSearch) {
        savedStore.remove(id: item.id)
        refreshSaved()
    }

    // Recent logic
    fileprivate func refreshRecent() {
        recent = recentStore.list()
    }
    fileprivate func performRecentSearch(_ item: RecentSearch) {
        state.tags = item.query
        state.rating = item.rating
        if let s = item.sort { state.sort = s }
        state.resetForNewSearch()
        recentStore.addOrTouch(
            query: item.query, rating: item.rating, sort: item.sort ?? state.sort)
        refreshRecent()
    }
}
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
                        #if os(macOS)
                            .onHover { hovering in
                                if hovering { selectedIndex = idx }
                            }
                        #endif
                        if idx < items.count - 1 { Divider() }
                    }
                }
                .onChangeCompat(of: selectedIndex) { newValue in
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
        var searchStart = lower.startIndex
        while let r = lower.range(of: query, range: searchStart..<lower.endIndex) {
            if let start = AttributedString.Index(r.lowerBound, within: attr),
                let end = AttributedString.Index(r.upperBound, within: attr)
            {
                attr[start..<end].inlinePresentationIntent = .stronglyEmphasized
            }
            searchStart = r.upperBound
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
