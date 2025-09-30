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
    @Environment(\.appDependencies) private var dependencies
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var lastErrorMessage: String? = nil
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
        .focusedSceneValue(
            \.gridActions,
            GridActions(
                prev: {
                    guard !isLoading, search.page > 1 else { return }
                    Task { await load(page: max(1, search.page - 1), replace: true) }
                },
                next: {
                    guard !isLoading else { return }
                    Task { await load(page: search.page + 1, replace: true) }
                },
                refresh: {
                    Task { await refresh() }
                }
            )
        )
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
                        guard search.page > 1 else { return }
                        Task { await load(page: max(1, search.page - 1), replace: true) }
                    } label: {
                        Label("Prev", systemImage: "chevron.left")
                    }
                    .disabled(isLoading || search.page <= 1)
                    Text("Page \(search.page)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await load(page: search.page + 1, replace: true) }
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
        await load(page: 1, replace: true)
    }

    @MainActor
    private func load(page: Int, replace: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = try await dependencies.searchPosts.execute(
                query: search.danbooruQuery,
                page: page,
                limit: search.pageSize
            )
            if replace {
                posts = next
            } else {
                posts.append(contentsOf: next)
            }
            self.search.page = max(1, page)
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
        .background(
            LinearGradient(
                colors: [
                    Color("PrimaryBackground"),
                    Color("SecondaryBackground").opacity(0.95),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
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
