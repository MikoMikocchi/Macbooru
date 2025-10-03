import CryptoKit
import Foundation
import SwiftUI
import os

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

actor ImageDiskCache {
    static let shared = ImageDiskCache()

    private let directory: URL
    private let fileManager: FileManager
    private var maxSizeBytes: Int
    private let defaults = UserDefaults.standard
    private let limitKey = "imageCache.maxSizeBytes"
    private let defaultLimitBytes = 256 * 1024 * 1024

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        let dir =
            base?.appendingPathComponent("MacbooruImageCache", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
                "MacbooruImageCache",
                isDirectory: true
            )
        directory = dir
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let storedLimit = defaults.integer(forKey: limitKey)
        maxSizeBytes = storedLimit > 0 ? storedLimit : defaultLimitBytes
    }

    func data(for url: URL) -> Data? {
        let path = directory.appendingPathComponent(filename(for: url))
        return try? Data(contentsOf: path)
    }

    func store(_ data: Data, for url: URL) {
        let path = directory.appendingPathComponent(filename(for: url))
        do {
            try data.write(to: path, options: [.atomic])
        } catch {
            logger.warning("Failed to write image cache: \(error.localizedDescription)")
        }
        enforceLimitIfNeeded()
    }

    private func filename(for url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func currentUsageBytes() -> Int {
        guard
            let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
        else { return 0 }
        return files.reduce(0) { partial, url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            let size = values?.fileSize ?? 0
            return partial + size
        }
    }

    func limitInMegabytes() -> Int {
        max(1, maxSizeBytes / 1_048_576)
    }

    func updateLimit(megabytes: Int) {
        maxSizeBytes = max(1, megabytes) * 1_048_576
        defaults.set(maxSizeBytes, forKey: limitKey)
        enforceLimitIfNeeded()
    }

    func clear() {
        guard
            let files = try? fileManager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: [])
        else {
            return
        }
        for url in files {
            try? fileManager.removeItem(at: url)
        }
    }

    private func enforceLimitIfNeeded() {
        guard maxSizeBytes > 0 else { return }
        guard
            var files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
        else { return }

        var totalSize = files.reduce(0) { partial, url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            let size = values?.fileSize ?? 0
            return partial + size
        }

        guard totalSize > maxSizeBytes else { return }

        files.sort { lhs, rhs in
            let lhsDate =
                (try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate)
                ?? Date.distantPast
            let rhsDate =
                (try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate)
                ?? Date.distantPast
            return lhsDate < rhsDate
        }

        for url in files {
            guard totalSize > maxSizeBytes else { break }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            let size = values?.fileSize ?? 0
            try? fileManager.removeItem(at: url)
            totalSize -= size
        }
    }

    private let logger = Logger(subsystem: "Macbooru", category: "Caching")
}

final class ThrottledImageLoader {
    static let shared = ThrottledImageLoader()

    private let session: URLSession
    private let logger = Logger.imageLoader

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = false
        cfg.httpMaximumConnectionsPerHost = 3
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 30
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.urlCache = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        cfg.httpAdditionalHeaders = [
            "User-Agent":
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept": "image/jpeg,image/png,*/*;q=0.5",
        ]
        self.session = URLSession(configuration: cfg)
    }

    func load(_ url: URL) async throws -> PlatformImage {
        if let cached = await ImageMemoryCache.shared.image(for: url) { return cached }
        if let diskData = await ImageDiskCache.shared.data(for: url) {
            if let diskImage = try? await decodeImage(data: diskData) {
                await ImageMemoryCache.shared.set(diskImage, for: url)
                logger.debug(
                    "Loaded image from disk cache: \(url.lastPathComponent, privacy: .public)")
                return diskImage
            } else {
                logger.debug(
                    "Disk cache entry failed to decode for \(url.lastPathComponent, privacy: .public)"
                )
            }
        }
        var req = URLRequest(url: url)
        req.setValue("https://danbooru.donmai.us", forHTTPHeaderField: "Referer")
        req.setValue("image/jpeg,image/png,*/*;q=0.5", forHTTPHeaderField: "Accept")
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent")
        var lastError: Error? = nil
        for attempt in 0..<3 {
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode)
                else {
                    throw URLError(.badServerResponse)
                }
                let image = try await decodeImage(data: data)
                await ImageMemoryCache.shared.set(image, for: url)
                await ImageDiskCache.shared.store(data, for: url)
                logger.debug(
                    "Loaded image from network: \(url.lastPathComponent, privacy: .public)")
                return image
            } catch {
                lastError = error
                logger.error(
                    "Image load error (attempt \(attempt + 1, privacy: .public)) for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                let delay = UInt64(pow(2.0, Double(attempt)) * 200_000_000)  // 0.2s, 0.4s, 0.8s
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

    private func decodeImage(data: Data) async throws -> PlatformImage {
        #if os(macOS)
            let image: NSImage? = await MainActor.run {
                if let rep = NSBitmapImageRep(data: data) {
                    let size = NSSize(width: max(1, rep.pixelsWide), height: max(1, rep.pixelsHigh))
                    rep.size = size
                    let image = NSImage(size: size)
                    image.addRepresentation(rep)
                    image.isTemplate = false
                    return image
                }
                if let src = CGImageSourceCreateWithData(data as CFData, nil),
                    let cg = CGImageSourceCreateImageAtIndex(
                        src, 0, [kCGImageSourceShouldCache: true] as CFDictionary)
                {
                    let size = NSSize(width: cg.width, height: cg.height)
                    let image = NSImage(cgImage: cg, size: size)
                    image.isTemplate = false
                    return image
                }
                if let image = NSImage(data: data) {
                    if image.size == .zero,
                        let rep = image.representations.first as? NSBitmapImageRep
                    {
                        image.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
                    }
                    image.isTemplate = false
                    return image
                }
                return nil
            }
            guard let image else { throw URLError(.cannotDecodeContentData) }
            logger.debug(
                "Decoded image (macOS) \(Int(image.size.width))x\(Int(image.size.height))"
            )
            return image
        #else
            guard let image = UIImage(data: data, scale: UIScreen.main.scale) else {
                throw URLError(.cannotDecodeContentData)
            }
            logger.debug(
                "Decoded image (iOS) \(Int(image.size.width))x\(Int(image.size.height))"
            )
            return image
        #endif
    }
}

struct RemoteImage: View {
    let candidates: [URL]
    let height: CGFloat
    let contentMode: ContentMode
    var animateFirstAppearance: Bool = true
    var animateUpgrades: Bool = false
    var interpolation: Image.Interpolation = .high
    var decoratedBackground: Bool = true
    var cornerRadius: CGFloat = 8

    @Environment(\.lowPerformance) private var lowPerf
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
                        .interpolation(lowPerf ? .none : interpolation)
                        .modifier(Scaled(contentMode: contentMode))
                #else
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(lowPerf ? .none : interpolation)
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
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
        .background(
            Group {
                if decoratedBackground && !lowPerf {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(Rectangle())
        .task(id: candidates) { await load() }
    }

    private func load() async {
        if Task.isCancelled { return }
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
            if Task.isCancelled { return }
            do {
                let img = try await ThrottledImageLoader.shared.load(url)
                if Task.isCancelled { return }
                let newPixels = pixelCountFor(img)
                // показать первый успешный вариант
                if firstShownIndex == nil {
                    firstShownIndex = idx
                    await MainActor.run {
                        if Task.isCancelled { return }
                        if animateFirstAppearance && !lowPerf {
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
                } else if newPixels > pixelCount {  // улучшение — заменить
                    await MainActor.run {
                        if Task.isCancelled { return }
                        if animateUpgrades && !lowPerf {
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
        if !Task.isCancelled, firstShownIndex == nil {
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

extension Logger {
    private static let subsystemIdentifier = "Macbooru"
    fileprivate static let imageLoader = Logger(
        subsystem: subsystemIdentifier, category: "ImageLoader")
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
