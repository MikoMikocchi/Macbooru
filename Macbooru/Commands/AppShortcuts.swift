import SwiftUI


struct GridActions {
    var prev: (() -> Void)?
    var next: (() -> Void)?
    var refresh: (() -> Void)?
}

struct DetailActions {
    var prev: (() -> Void)?
    var next: (() -> Void)?
}

struct SearchActions {
    var focusSearch: (() -> Void)?
    var setPageSize15: (() -> Void)?
    var setPageSize30: (() -> Void)?
    var setPageSize60: (() -> Void)?
}

private struct GridActionsKey: FocusedValueKey { typealias Value = GridActions }
private struct DetailActionsKey: FocusedValueKey { typealias Value = DetailActions }
private struct SearchActionsKey: FocusedValueKey { typealias Value = SearchActions }

extension FocusedValues {
    var gridActions: GridActions? {
        get { self[GridActionsKey.self] }
        set { self[GridActionsKey.self] = newValue }
    }
    var detailActions: DetailActions? {
        get { self[DetailActionsKey.self] }
        set { self[DetailActionsKey.self] = newValue }
    }
    var searchActions: SearchActions? {
        get { self[SearchActionsKey.self] }
        set { self[SearchActionsKey.self] = newValue }
    }
}

struct AppShortcuts: Commands {
    @FocusedValue(\.gridActions) private var grid
    @FocusedValue(\.detailActions) private var detail
    @FocusedValue(\.searchActions) private var search

    var body: some Commands {
        CommandMenu(L10n.Commands.navigation) {
            Button(L10n.Commands.prevPage) { grid?.prev?() }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .disabled(grid?.prev == nil)
            Button(L10n.Commands.nextPage) { grid?.next?() }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .disabled(grid?.next == nil)
            Divider()
            Button(L10n.Commands.prevPost) { detail?.prev?() }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(detail?.prev == nil)
            Button(L10n.Commands.nextPost) { detail?.next?() }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(detail?.next == nil)
            Button(L10n.Commands.prevPost) { detail?.prev?() }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(detail?.prev == nil)
            Button(L10n.Commands.nextPost) { detail?.next?() }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(detail?.next == nil)
            Divider()
            Button(L10n.Grid.refresh) { grid?.refresh?() }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(grid?.refresh == nil)
        }
        CommandMenu(L10n.Commands.search) {
            Button(L10n.Commands.focusSearch) { search?.focusSearch?() }
                .keyboardShortcut("f", modifiers: [.command])
            Divider()
            Button(L10n.Commands.pageSize15) { search?.setPageSize15?() }
                .keyboardShortcut("1", modifiers: [.command])
            Button(L10n.Commands.pageSize30) { search?.setPageSize30?() }
                .keyboardShortcut("2", modifiers: [.command])
            Button(L10n.Commands.pageSize60) { search?.setPageSize60?() }
                .keyboardShortcut("3", modifiers: [.command])
        }
    }
}
