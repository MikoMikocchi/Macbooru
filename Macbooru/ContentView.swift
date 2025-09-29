//
//  ContentView.swift
//  Macbooru
//
//  Created by Михаил Мацкевич on 29.09.2025.
//

import SwiftUI
import SwiftData

struct PostGridView: View {
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var page = 1
    private let repo = PostsRepositoryImpl(client: DanbooruClient())

    private let columns = Array(repeating: GridItem(.flexible(minimum: 160), spacing: 12), count: 5)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(posts) { post in
                    NavigationLink(value: post) {
                        RemoteImage(
                            candidates: [post.previewURL, post.largeURL, post.fileURL].compactMap { $0 },
                            height: 160,
                            contentMode: .fill,
                            animateFirstAppearance: true,
                            animateUpgrades: false
                        )
                            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
                            .contentShape(Rectangle())
                    }
                    .id(post.id)
                    .buttonStyle(.plain)
                    .onAppear {
                        // Триггер подгрузки следующей страницы при появлении последних элементов
                        if post.id == posts.suffix(5).first?.id {
                            Task { await load(page: page) }
                        }
                    }
                }
                if isLoading { ProgressView().padding() }
            }
            .padding(12)
        }
        .navigationTitle("Posts")
        .task { await load(page: 1) }
        .onAppear {
            // дополнительная подгрузка при прокрутке можно добавить позже с GeometryReader
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await load(page: page) }
                } label: { Label("More", systemImage: "ellipsis.circle") }
                .disabled(isLoading)
            }
        }
    }

    @MainActor
    private func refresh() async {
        page = 1
        posts.removeAll()
        await load(page: 1)
    }

    @MainActor
    private func load(page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = try await repo.recent(page: page, limit: 30)
            // Убираем дубликаты по id, сохраняя порядок
            let existingIDs = Set(posts.map { $0.id })
            let filtered = next.filter { !existingIDs.contains($0.id) }
            posts.append(contentsOf: filtered)
            self.page = page + 1
        } catch {
            // TODO: показать тост/алерт
            print("Failed to load posts: \(error)")
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            PostGridView()
                .navigationDestination(for: Post.self) { post in
                    PostDetailView(post: post)
                }
        }
    }
}

struct PostDetailView: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteImage(
                candidates: [post.largeURL, post.fileURL, post.previewURL].compactMap { $0 },
                height: 420,
                contentMode: .fit,
                animateFirstAppearance: false,
                animateUpgrades: false
            )
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("ID: \(post.id)").font(.headline)
            if let rating = post.rating { Text("Rating: \(rating)") }
            if let tags = post.tagString { Text(tags).lineLimit(3) }
            if let src = post.source { Link("Source", destination: URL(string: src) ?? URL(string: "https://danbooru.donmai.us")!) }
            Spacer()
        }
        .padding()
        .frame(maxWidth: 900, alignment: .leading)
        .navigationTitle("Post #\(post.id)")
    }
}

#Preview {
    ContentView()
}
