//
//  MacbooruApp.swift
//  Macbooru
//
//  Created by Михаил Мацкевич on 29.09.2025.
//

import SwiftUI

@main
struct MacbooruApp: App {
    private let dependencies = AppDependencies.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDependencies, dependencies)
        }
        .commands { AppShortcuts() }
    }
}
