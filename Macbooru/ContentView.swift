//
//  ContentView.swift
//  Macbooru
//
//  Created by Михаил Мацкевич on 29.09.2025.
//

import SwiftData
import SwiftUI

struct PostGridView: View {
    @ObservedObject var search: SearchState
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var lastErrorMessage: String? = nil
    private let repo = PostsRepositoryImpl(client: DanbooruClient())
    @State private var columns: [GridItem] = []
    private let gridSpacing: CGFloat = 24

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(posts) { post in
                    NavigationLink(value: post) {
                        PostTileView(post: post, height: search.tileSize.height)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .id(post.id)
                    .buttonStyle(.plain)
                    .frame(height: search.tileSize.height)
                    .onAppear {
                        // Триггер подгрузки следующей страницы при появлении последних элементов
                        if post.id == posts.suffix(5).first?.id {
                            Task { await load(page: search.page) }
                        }
                    }
                }
                if isLoading { ProgressView().padding() }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .navigationTitle("Posts")
        .task { await load(page: 1) }
        .onChange(of: search.tileSize) { _ in recomputeColumns() }
        .onChange(of: search.searchTrigger) { _ in Task { await refresh() } }
        .onAppear { recomputeColumns() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .status) {
                HStack(spacing: 8) {
                    Button {
                        guard search.page > 2 else { return }
                        Task { await load(page: max(1, search.page - 2)) }
                    } label: {
                        Label("Prev", systemImage: "chevron.left")
                    }
                    .disabled(isLoading || search.page <= 2)
                    Button {
                        Task { await load(page: search.page) }
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = lastErrorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(msg)
                    Button("Retry") { Task { await refresh() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 12)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { lastErrorMessage = nil }
                    }
                }
            }
        }
    }

    @MainActor
    private func refresh() async {
        search.page = 1
        posts.removeAll()
        await load(page: 1)
    }

    @MainActor
    private func load(page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next: [Post]
            if let q = search.danbooruQuery {
                next = try await repo.byTags(q, page: page, limit: 30)
            } else {
                next = try await repo.recent(page: page, limit: 30)
            }
            // Убираем дубликаты по id, сохраняя порядок
            let existingIDs = Set(posts.map { $0.id })
            let filtered = next.filter { !existingIDs.contains($0.id) }
            posts.append(contentsOf: filtered)
            self.search.page = page + 1
        } catch {
            withAnimation {
                lastErrorMessage = "Failed to load posts: \(error.localizedDescription)"
            }
            print("Failed to load posts: \(error)")
        }
    }

    private func recomputeColumns() {
        columns = [
            GridItem(.adaptive(minimum: search.tileSize.minColumnWidth), spacing: gridSpacing)
        ]
    }
}

struct ContentView: View {
    @StateObject private var search = SearchState()
    var body: some View {
        NavigationSplitView {
            SidebarView(state: search) {
                // запуск поиска
                Task { await resetAndSearch() }
            }
            .frame(minWidth: 260, maxWidth: 320)
        } detail: {
            NavigationStack {
                PostGridView(search: search)
                    .padding(.trailing, 8)
                    .navigationDestination(for: Post.self) { post in
                        PostDetailView(post: post)
                    }
            }
        }
        .environmentObject(search)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
    }

    @MainActor
    private func resetAndSearch() async {
        // сброс грида и загрузка первой страницы под новый запрос
        // фактическая очистка в PostGridView происходит по refresh()
        // здесь просто увеличим page и дадим сигнал обновиться
        // (упрощённо — можно сделать через ObservableObject/Publisher позже)
        // Ничего не делаем здесь, так как PostGridView сам вызывает .task { load(page:1) }
    }
}

#Preview {
    ContentView()
}
