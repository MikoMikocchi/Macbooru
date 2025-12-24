import SwiftUI
#if os(macOS)
    import AppKit
#endif

struct ZoomableImageView<Content: View>: View {
    @Binding var zoom: CGFloat
    @Binding var lastZoom: CGFloat
    @Binding var offset: CGSize
    @Binding var lastDrag: CGSize
    
    let contentBaseHeight: CGFloat
    let containerSize: CGSize
    let imageAspectRatio: CGFloat?
    let buildContextMenu: (() -> NSMenu)?
    let content: Content
    
    init(
        zoom: Binding<CGFloat>,
        lastZoom: Binding<CGFloat>,
        offset: Binding<CGSize>,
        lastDrag: Binding<CGSize>,
        contentBaseHeight: CGFloat,
        containerSize: CGSize,
        imageAspectRatio: CGFloat?,
        buildContextMenu: (() -> NSMenu)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._zoom = zoom
        self._lastZoom = lastZoom
        self._offset = offset
        self._lastDrag = lastDrag
        self.contentBaseHeight = contentBaseHeight
        self.containerSize = containerSize
        self.imageAspectRatio = imageAspectRatio
        self.buildContextMenu = buildContextMenu
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(zoom)
            .offset(offset)
            .onChange(of: zoom) { _, _ in
                offset = clampedOffset(
                    offset,
                    containerSize: containerSize,
                    contentBaseHeight: contentBaseHeight
                )
            }
            #if os(macOS)
            .overlay(
                PanZoomProxy(
                    onPan: { delta in
                        let candidate = CGSize(
                            width: offset.width + delta.width,
                            height: offset.height + delta.height
                        )
                        offset = softClampedOffset(
                            candidate,
                            containerSize: containerSize,
                            contentBaseHeight: contentBaseHeight
                        )
                        lastDrag = offset
                    },
                    onPanEnd: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            offset = hardClampedOffset(
                                offset,
                                containerSize: containerSize,
                                contentBaseHeight: contentBaseHeight
                            )
                        }
                        lastDrag = offset
                    },
                    onMagnify: { scale, location in
                        let old = zoom
                        let next = min(6.0, max(0.5, old * scale))
                        if old != 0, next != old {
                            let factor = next / old
                            let center = CGPoint(
                                x: containerSize.width / 2,
                                y: containerSize.height / 2
                            )
                            let dx = (location.x - center.x) * (factor - 1)
                            let dy = (location.y - center.y) * (factor - 1)
                            offset = CGSize(
                                width: offset.width - dx,
                                height: offset.height - dy
                            )
                        }
                        zoom = next
                        lastZoom = next
                        offset = hardClampedOffset(
                            offset,
                            containerSize: containerSize,
                            contentBaseHeight: contentBaseHeight
                        )
                    },
                    onDoubleClick: { _ in
                        resetZoom()
                    },
                    buildContextMenu: buildContextMenu
                )
            )
            #else
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoom = min(6.0, max(0.5, lastZoom * value))
                    }
                    .onEnded { _ in
                        lastZoom = zoom
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { g in
                        let candidate = CGSize(
                            width: lastDrag.width + g.translation.width,
                            height: lastDrag.height + g.translation.height
                        )
                        offset = softClampedOffset(
                            candidate,
                            containerSize: containerSize,
                            contentBaseHeight: contentBaseHeight
                        )
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            offset = hardClampedOffset(
                                offset,
                                containerSize: containerSize,
                                contentBaseHeight: contentBaseHeight
                            )
                        }
                        lastDrag = offset
                    }
            )
            #endif
            .animation(.easeInOut(duration: 0.15), value: zoom)
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.15)) {
            zoom = 1.0
            lastZoom = 1.0
            offset = .zero
            lastDrag = .zero
        }
    }
    
    // MARK: - Helpers

    private func clampedOffset(
        _ candidate: CGSize, containerSize: CGSize, contentBaseHeight: CGFloat
    ) -> CGSize {
        var contentWidth: CGFloat
        var contentHeight: CGFloat

        if let aspect = imageAspectRatio {
            // Базовая (fit) ширина/высота до применения зума
            let baseWidthFit = min(containerSize.width, contentBaseHeight * aspect)
            let baseHeightFit = min(contentBaseHeight, containerSize.width / aspect)
            contentWidth = baseWidthFit * zoom
            contentHeight = baseHeightFit * zoom
        } else {
            contentWidth = containerSize.width * zoom
            contentHeight = contentBaseHeight * zoom
        }

        let allowX: CGFloat = max(0, (contentWidth - containerSize.width) / 2)
        let allowY: CGFloat = max(0, (contentHeight - containerSize.height) / 2)

        let clampedX = min(max(candidate.width, -allowX), allowX)
        let clampedY = min(max(candidate.height, -allowY), allowY)
        return CGSize(width: clampedX, height: clampedY)
    }

    private func softClampedOffset(
        _ candidate: CGSize, containerSize: CGSize, contentBaseHeight: CGFloat
    ) -> CGSize {
        let allow = allowedHalfOverflow(
            containerSize: containerSize, contentBaseHeight: contentBaseHeight)
        let k: CGFloat = 0.35
        let overX = overflow(candidate.width, allow: allow.x)
        let overY = overflow(candidate.height, allow: allow.y)
        let softX = candidate.width - sign(candidate.width) * max(0, abs(overX)) * (1 - k)
        let softY = candidate.height - sign(candidate.height) * max(0, abs(overY)) * (1 - k)
        return CGSize(width: softX, height: softY)
    }

    private func hardClampedOffset(
        _ candidate: CGSize, containerSize: CGSize, contentBaseHeight: CGFloat
    ) -> CGSize {
        clampedOffset(candidate, containerSize: containerSize, contentBaseHeight: contentBaseHeight)
    }

    private func allowedHalfOverflow(containerSize: CGSize, contentBaseHeight: CGFloat) -> (
        x: CGFloat, y: CGFloat
    ) {
        var contentWidth: CGFloat
        var contentHeight: CGFloat
        if let aspect = imageAspectRatio {
            let baseWidthFit = min(containerSize.width, contentBaseHeight * aspect)
            let baseHeightFit = min(contentBaseHeight, containerSize.width / aspect)
            contentWidth = baseWidthFit * zoom
            contentHeight = baseHeightFit * zoom
        } else {
            contentWidth = containerSize.width * zoom
            contentHeight = contentBaseHeight * zoom
        }
        let allowX = max(0, (contentWidth - containerSize.width) / 2)
        let allowY = max(0, (contentHeight - containerSize.height) / 2)
        return (allowX, allowY)
    }

    private func overflow(_ value: CGFloat, allow: CGFloat) -> CGFloat {
        if value > allow { return value - allow }
        if value < -allow { return value + allow }
        return 0
    }

    private func sign(_ value: CGFloat) -> CGFloat { value >= 0 ? 1 : -1 }
}

#if os(macOS)
struct PanZoomProxy: NSViewRepresentable {
    typealias NSViewType = PanZoomNSView
    var onPan: (CGSize) -> Void
    var onPanEnd: (() -> Void)? = nil
    var onMagnify: (CGFloat, CGPoint) -> Void
    var onDoubleClick: ((CGPoint) -> Void)? = nil
    var buildContextMenu: (() -> NSMenu)? = nil

    func makeNSView(context: Context) -> PanZoomNSView {
        let view = PanZoomNSView()
        view.onPan = onPan
        view.onPanEnd = onPanEnd
        view.onMagnify = onMagnify
        view.onDoubleClick = onDoubleClick
        view.buildContextMenu = buildContextMenu
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: PanZoomNSView, context: Context) {
        nsView.onPan = onPan
        nsView.onPanEnd = onPanEnd
        nsView.onMagnify = onMagnify
        nsView.onDoubleClick = onDoubleClick
        nsView.buildContextMenu = buildContextMenu
    }
}

final class PanZoomNSView: NSView {
    var onPan: ((CGSize) -> Void)?
    var onPanEnd: (() -> Void)?
    var onMagnify: ((CGFloat, CGPoint) -> Void)?
    var onDoubleClick: ((CGPoint) -> Void)?
    var buildContextMenu: (() -> NSMenu)?

    private var lastMousePoint: NSPoint?

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        onPan?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
        if event.phase == .ended || event.momentumPhase == .ended {
            onPanEnd?()
        }
    }

    override func magnify(with event: NSEvent) {
        let scale = 1 + event.magnification
        let location = convert(event.locationInWindow, from: nil)
        onMagnify?(scale, location)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2 {
            onDoubleClick?(point)
            return
        }
        lastMousePoint = point
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let last = lastMousePoint {
            onPan?(CGSize(width: point.x - last.x, height: point.y - last.y))
        }
        lastMousePoint = point
    }

    override func mouseUp(with event: NSEvent) {
        lastMousePoint = nil
        onPanEnd?()
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = buildContextMenu?() {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }
}
#endif

