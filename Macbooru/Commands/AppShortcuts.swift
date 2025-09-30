import SwiftUI

// Контекстные действия для грида (страницы/обновление)
struct GridActions {
    var prev: (() -> Void)?
    var next: (() -> Void)?
    var refresh: (() -> Void)?
}

// Контекстные действия для поиска (фокус/размер страницы)
struct SearchActions {
    var focusSearch: (() -> Void)?
    var setPageSize15: (() -> Void)?
    var setPageSize30: (() -> Void)?
    var setPageSize60: (() -> Void)?
}

private struct GridActionsKey: FocusedValueKey { typealias Value = GridActions }
private struct SearchActionsKey: FocusedValueKey { typealias Value = SearchActions }

extension FocusedValues {
    var gridActions: GridActions? {
        get { self[GridActionsKey.self] }
        set { self[GridActionsKey.self] = newValue }
    }
    var searchActions: SearchActions? {
        get { self[SearchActionsKey.self] }
        set { self[SearchActionsKey.self] = newValue }
    }
}

struct AppShortcuts: Commands {
    @FocusedValue(\.gridActions) private var grid
    @FocusedValue(\.searchActions) private var search

    var body: some Commands {
        CommandMenu("Navigation") {
            Button("Previous Page") { grid?.prev?() }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .disabled(grid?.prev == nil)
            Button("Next Page") { grid?.next?() }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .disabled(grid?.next == nil)
            Divider()
            Button("Refresh") { grid?.refresh?() }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(grid?.refresh == nil)
        }
        CommandMenu("Search") {
            Button("Focus Search") { search?.focusSearch?() }
                .keyboardShortcut("f", modifiers: [.command])
            Divider()
            Button("Page Size: 15") { search?.setPageSize15?() }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Page Size: 30") { search?.setPageSize30?() }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Page Size: 60") { search?.setPageSize60?() }
                .keyboardShortcut("3", modifiers: [.command])
        }
    }
}
