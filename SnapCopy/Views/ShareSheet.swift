import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityViewController.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

final class SnapCopyShareTextItemSource: NSObject, UIActivityItemSource {
    private let caption: String
    private let captionURL: URL

    init(caption: String, captionURL: URL) {
        self.caption = caption
        self.captionURL = captionURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        caption
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if SnapCopyShareActivityType.isSaveToFiles(activityType) {
            return captionURL
        }

        return caption
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "SnapCopy 文案"
    }
}

final class SnapCopyShareImageItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let imageURL: URL

    init(image: UIImage, imageURL: URL) {
        self.image = image
        self.imageURL = imageURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if SnapCopyShareActivityType.isSaveToFiles(activityType) ||
            SnapCopyShareActivityType.isWeChat(activityType) {
            return imageURL
        }

        return image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.jpeg.identifier
    }
}

enum SnapCopyShareActivityType {
    static func isSaveToFiles(_ activityType: UIActivity.ActivityType?) -> Bool {
        guard let rawValue = activityType?.rawValue else {
            return false
        }

        return rawValue.contains("SaveToFiles") ||
        rawValue.contains("DocumentManager") ||
        rawValue.contains("AddToiCloudDrive")
    }

    static func isWeChat(_ activityType: UIActivity.ActivityType?) -> Bool {
        guard let rawValue = activityType?.rawValue.lowercased() else {
            return false
        }

        return rawValue.contains("tencent.xin") ||
        rawValue.contains("wechat") ||
        rawValue.contains("weixin")
    }
}
