//
//  MacbooruApp.swift
//  Macbooru
//
//  Created by Михаил Мацкевич on 29.09.2025.
//

import SwiftUI

@main
struct MacbooruApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands { AppShortcuts() }
    }
}
