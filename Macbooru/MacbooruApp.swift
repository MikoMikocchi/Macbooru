//
//  MacbooruApp.swift
//  Macbooru
//
//  Created by Михаил Мацкевич on 29.09.2025.
//

import SwiftUI

@main
struct MacbooruApp: App {
    @StateObject private var dependenciesStore: AppDependenciesStore
    @StateObject private var search = SearchState()

    @MainActor
    init() {
        _dependenciesStore = StateObject(wrappedValue: AppDependenciesStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDependencies, dependenciesStore.dependencies)
                .environmentObject(dependenciesStore)
                .environmentObject(search)
        }
        .commands { AppShortcuts() }

        #if os(macOS)
            Settings {
                SettingsView()
                    .environment(\.appDependencies, dependenciesStore.dependencies)
                    .environmentObject(dependenciesStore)
                    .environmentObject(search)
                    .frame(minWidth: 920, maxWidth: 960, minHeight: 700)
            }
        #endif
    }
}
