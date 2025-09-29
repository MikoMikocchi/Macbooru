import Foundation
import SwiftUI
#if os(macOS)
import AppKit
import ImageIO
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

actor ImageMemoryCache {
    static let shared = ImageMemoryCache()
    private var cache = NSCache<NSURL, PlatformImage>()
    func image(for url: URL) -> PlatformImage? { cache.object(forKey: url as NSURL) }
    func set(_ image: PlatformImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

final class ThrottledImageLoader {
    static let shared = ThrottledImageLoader()

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
    cfg.waitsForConnectivity = false
    cfg.httpMaximumConnectionsPerHost = 3
    cfg.timeoutIntervalForRequest = 15
    cfg.timeoutIntervalForResource = 30
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.urlCache = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept": "image/jpeg,image/png,*/*;q=0.5"
        ]
        self.session = URLSession(configuration: cfg)
    }

    func load(_ url: URL) async throws -> PlatformImage {
        if let cached = await ImageMemoryCache.shared.image(for: url) { return cached }
        var req = URLRequest(url: url)
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
    req.setValue("image/jpeg,image/png,*/*;q=0.5", forHTTPHeaderField: "Accept")
    req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        var lastError: Error? = nil
        for attempt in 0..<3 {
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let ctype = http.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
                // Диагностика: какой формат реально приходит
                print("Image content-type=\(ctype) url=\(url.lastPathComponent)")
        #if os(macOS)
                        // Надежное декодирование через NSBitmapImageRep -> NSImage с валидным size
                        let img: NSImage? = await MainActor.run {
                            if let rep = NSBitmapImageRep(data: data) {
                                // Обеспечим, что размер не нулевой
                                let size = NSSize(width: max(1, rep.pixelsWide), height: max(1, rep.pixelsHigh))
                                rep.size = size
                                let image = NSImage(size: size)
                                image.addRepresentation(rep)
                                image.isTemplate = false
                                return image
                            }
                            if let src = CGImageSourceCreateWithData(data as CFData, nil),
                               let cg = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: true] as CFDictionary) {
                                let size = NSSize(width: cg.width, height: cg.height)
                                let image = NSImage(cgImage: cg, size: size)
                                image.isTemplate = false
                                return image
                            }
                            if let image = NSImage(data: data) {
                                if image.size == .zero, let rep = image.representations.first as? NSBitmapImageRep {
                                    image.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
                                }
                                image.isTemplate = false
                                return image
                            }
                            return nil
                        }
                        guard let img else { throw URLError(.cannotDecodeContentData) }
                        print("Decoded image size: \(Int(img.size.width))x\(Int(img.size.height)) for \(url.lastPathComponent)")
        #else
                guard let img = UIImage(data: data, scale: UIScreen.main.scale) else { throw URLError(.cannotDecodeContentData) }
        #endif
                await ImageMemoryCache.shared.set(img, for: url)
                return img
            } catch {
                lastError = error
                print("Image load error: \(url.absoluteString) — \(error.localizedDescription)")
                let delay = UInt64(pow(2.0, Double(attempt)) * 200_000_000) // 0.2s, 0.4s, 0.8s
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        throw lastError ?? URLError(.cannotLoadFromNetwork)
    }

    func load(from candidates: [URL]) async throws -> PlatformImage {
        for url in candidates {
            do {
                let img = try await load(url)
                return img
            } catch {
                // попробуем следующий вариант
                continue
            }
        }
        throw URLError(.cannotLoadFromNetwork)
    }
}

struct RemoteImage: View {
    let candidates: [URL]
    let height: CGFloat
    let contentMode: ContentMode
    var animateFirstAppearance: Bool = true
    var animateUpgrades: Bool = false

    @State private var image: PlatformImage? = nil
    @State private var pixelCount: Int = 0
    @State private var isLoading = false
    @State private var lastError: Error? = nil
    @State private var didShowFirst = false

    var body: some View {
        ZStack {
            if let image {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .modifier(Scaled(contentMode: contentMode))
                #else
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .modifier(Scaled(contentMode: contentMode))
                #endif
            } else if isLoading {
                ProgressView()
            } else if lastError != nil {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await load() }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .task(id: candidates) { await load() }
    }

    private func load() async {
        await MainActor.run {
            lastError = nil
            image = nil
            isLoading = true
        }
        guard !candidates.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        // Прогрессивная загрузка: сначала быстрый превью, затем апгрейд до более крупного
        var firstShownIndex: Int? = nil
        for (idx, url) in candidates.enumerated() {
            do {
                let img = try await ThrottledImageLoader.shared.load(url)
                let newPixels = pixelCountFor(img)
                // показать первый успешный вариант
                if firstShownIndex == nil {
                    firstShownIndex = idx
                    await MainActor.run {
                        if animateFirstAppearance {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                self.image = img
                                self.pixelCount = newPixels
                            }
                        } else {
                            self.image = img
                            self.pixelCount = newPixels
                        }
                        self.isLoading = false
                        self.didShowFirst = true
                    }
                } else if newPixels > pixelCount { // улучшение — заменить
                    await MainActor.run {
                        if animateUpgrades {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                self.image = img
                                self.pixelCount = newPixels
                            }
                        } else {
                            self.image = img
                            self.pixelCount = newPixels
                        }
                    }
                }
            } catch {
                // просто идем дальше к следующему кандидату
                continue
            }
        }
        // если вообще ничего не удалось
        if firstShownIndex == nil {
            await MainActor.run {
                self.lastError = URLError(.cannotLoadFromNetwork)
                self.isLoading = false
            }
        }
    }

    private func pixelCountFor(_ img: PlatformImage) -> Int {
        #if os(macOS)
        return max(1, Int(img.size.width) * Int(img.size.height))
        #else
        let scale = img.scale
        return max(1, Int(img.size.width * scale) * Int(img.size.height * scale))
        #endif
    }
}

// Вспомогательный модификатор для выбора scaledToFit/scaledToFill
private struct Scaled: ViewModifier {
    let contentMode: ContentMode
    func body(content: Content) -> some View {
        switch contentMode {
        case .fit: content.scaledToFit()
        case .fill: content.scaledToFill()
        @unknown default: content.scaledToFill()
        }
    }
}
