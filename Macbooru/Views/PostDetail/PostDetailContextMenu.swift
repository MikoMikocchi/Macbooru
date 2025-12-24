import SwiftUI
#if os(macOS)
import AppKit

final class MenuActionTarget: NSObject {
    static var associatedKey: UInt8 = 0
    let fitAction: () -> Void
    let zoomInAction: () -> Void
    let zoomOutAction: () -> Void
    let centerAction: () -> Void
    let openPostPageAction: () -> Void
    let openLargeAction: () -> Void
    let openOriginalAction: () -> Void
    let copyTagsAction: () -> Void
    let copyPostURLAction: () -> Void
    let copyOriginalURLAction: () -> Void
    let copyImageAction: () -> Void
    let copySourceURLAction: () -> Void
    let downloadAction: () -> Void
    let revealDownloadsFolderAction: () -> Void

    init(
        fitAction: @escaping () -> Void,
        zoomInAction: @escaping () -> Void,
        zoomOutAction: @escaping () -> Void,
        centerAction: @escaping () -> Void,
        openPostPageAction: @escaping () -> Void,
        openLargeAction: @escaping () -> Void,
        openOriginalAction: @escaping () -> Void,
        copyTagsAction: @escaping () -> Void,
        copyPostURLAction: @escaping () -> Void,
        copyOriginalURLAction: @escaping () -> Void,
        copyImageAction: @escaping () -> Void,
        copySourceURLAction: @escaping () -> Void,
        downloadAction: @escaping () -> Void,
        revealDownloadsFolderAction: @escaping () -> Void
    ) {
        self.fitAction = fitAction
        self.zoomInAction = zoomInAction
        self.zoomOutAction = zoomOutAction
        self.centerAction = centerAction
        self.openPostPageAction = openPostPageAction
        self.openLargeAction = openLargeAction
        self.openOriginalAction = openOriginalAction
        self.copyTagsAction = copyTagsAction
        self.copyPostURLAction = copyPostURLAction
        self.copyOriginalURLAction = copyOriginalURLAction
        self.copyImageAction = copyImageAction
        self.copySourceURLAction = copySourceURLAction
        self.downloadAction = downloadAction
        self.revealDownloadsFolderAction = revealDownloadsFolderAction
    }

    @objc func fit() { fitAction() }
    @objc func zoomIn() { zoomInAction() }
    @objc func zoomOut() { zoomOutAction() }
    @objc func center() { centerAction() }
    @objc func openPostPage() { openPostPageAction() }
    @objc func openLarge() { openLargeAction() }
    @objc func openOriginal() { openOriginalAction() }
    @objc func copyTags() { copyTagsAction() }
    @objc func copyPostURL() { copyPostURLAction() }
    @objc func copyOriginalURL() { copyOriginalURLAction() }
    @objc func copyImage() { copyImageAction() }
    @objc func copySourceURL() { copySourceURLAction() }
    @objc func download() { downloadAction() }
    @objc func revealDownloadsFolder() { revealDownloadsFolderAction() }
}
#endif

