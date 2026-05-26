import Foundation
import ImagePlayground
import UIKit

enum CreativeImageAvailability: Equatable {
    case available
    case unavailable(String)
}

enum CreativeImageGenerationError: LocalizedError, Equatable {
    case unavailable
    case noOutput
    case cloudNotConfigured

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Image Playground is not available on this device."
        case .noOutput:
            "Image Playground did not return an image."
        case .cloudNotConfigured:
            "Cloud creative image generation is not configured yet."
        }
    }
}

enum CreativeImageGenerationSource {
    case appleImagePlayground
    case localTemplateFallback
}

struct CreativeImageGenerationResult {
    let image: UIImage
    let source: CreativeImageGenerationSource
}

protocol CreativeImageGenerating {
    @MainActor func availability() -> CreativeImageAvailability
    func generateImage(
        from sourceImage: UIImage,
        style: CreativeImageStyle,
        context: CaptionGenerationContext
    ) async throws -> CreativeImageGenerationResult
}

final class AppleCreativeImageService: CreativeImageGenerating {
    @MainActor
    func availability() -> CreativeImageAvailability {
        guard #available(iOS 18.4, *) else {
            return .unavailable("需要 iOS 18.4 或更新系统。")
        }

        if ImagePlaygroundViewController.isAvailable {
            return .available
        }

        return .unavailable("当前设备暂不可用，请确认 Apple Intelligence / Image Playground 已开启。")
    }

    func generateImage(
        from sourceImage: UIImage,
        style: CreativeImageStyle,
        context: CaptionGenerationContext
    ) async throws -> CreativeImageGenerationResult {
        guard #available(iOS 18.4, *) else {
            throw CreativeImageGenerationError.unavailable
        }

        do {
            let creator = try await ImageCreator()
            let playgroundStyle = preferredPlaygroundStyle(for: style, availableStyles: creator.availableStyles)
            var concepts: [ImagePlaygroundConcept] = [
                .text(style.prompt(context: context))
            ]

            if let cgImage = sourceImage.normalizedCGImage {
                concepts.append(.image(cgImage))
            }

            let imageSequence = creator.images(for: concepts, style: playgroundStyle, limit: 1)
            for try await createdImage in imageSequence {
                return CreativeImageGenerationResult(
                    image: UIImage(cgImage: createdImage.cgImage),
                    source: .appleImagePlayground
                )
            }
        } catch {
            if shouldUseLocalFallback(for: error) {
                let fallbackImage = await MainActor.run {
                    LocalCreativeImageRenderer().render(sourceImage, style: style)
                }
                return CreativeImageGenerationResult(image: fallbackImage, source: .localTemplateFallback)
            }

            throw error
        }

        throw CreativeImageGenerationError.noOutput
    }

    private func shouldUseLocalFallback(for error: Error) -> Bool {
        CreativeImageErrorInspector.isUnsupportedLanguage(error)
    }
}

enum CreativeImageErrorInspector {
    static func isUnsupportedLanguage(_ error: Error) -> Bool {
        if #available(iOS 18.4, *),
           let creatorError = error as? ImageCreator.Error,
           creatorError == .unsupportedLanguage {
            return true
        }

        let nsError = error as NSError
        let searchableText = [
            String(describing: error),
            error.localizedDescription,
            nsError.domain,
            nsError.userInfo.description
        ]
        .joined(separator: " ")
        .lowercased()

        return searchableText.contains("unsupportedlanguage") ||
            searchableText.contains("unsupported language") ||
            searchableText.contains("unsupported_language")
    }
}

private extension AppleCreativeImageService {
    @available(iOS 18.4, *)
    private func preferredPlaygroundStyle(
        for style: CreativeImageStyle,
        availableStyles: [ImagePlaygroundStyle]
    ) -> ImagePlaygroundStyle {
        let preferredStyle: ImagePlaygroundStyle
        switch style {
        case .cuteHandDrawn:
            preferredStyle = .sketch
        case .cover:
            preferredStyle = .illustration
        case .xiaohongshuSticker:
            preferredStyle = .animation
        }

        if availableStyles.contains(preferredStyle) {
            return preferredStyle
        }

        return availableStyles.first ?? preferredStyle
    }
}

final class LocalCreativeImageRenderer {
    func render(_ image: UIImage, style: CreativeImageStyle) -> UIImage {
        let canvasSize = canvasSize(for: style)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            drawBackground(in: context.cgContext, size: canvasSize, style: style)

            switch style {
            case .cuteHandDrawn:
                drawCuteHandDrawn(image, in: canvasSize)
            case .cover:
                drawCover(image, in: canvasSize)
            case .xiaohongshuSticker:
                drawSticker(image, in: canvasSize)
            }
        }
    }

    private func canvasSize(for style: CreativeImageStyle) -> CGSize {
        switch style {
        case .cover:
            CGSize(width: 1080, height: 1350)
        case .cuteHandDrawn, .xiaohongshuSticker:
            CGSize(width: 1080, height: 1080)
        }
    }

    private func drawBackground(in context: CGContext, size: CGSize, style: CreativeImageStyle) {
        let colors: [UIColor]
        switch style {
        case .cuteHandDrawn:
            colors = [
                UIColor(red: 1.00, green: 0.95, blue: 0.93, alpha: 1),
                UIColor(red: 0.94, green: 0.98, blue: 0.95, alpha: 1)
            ]
        case .cover:
            colors = [
                UIColor(red: 0.98, green: 0.91, blue: 0.93, alpha: 1),
                UIColor(red: 0.90, green: 0.95, blue: 0.96, alpha: 1)
            ]
        case .xiaohongshuSticker:
            colors = [
                UIColor(red: 1.00, green: 0.96, blue: 0.97, alpha: 1),
                UIColor(red: 0.98, green: 0.88, blue: 0.91, alpha: 1)
            ]
        }

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: [0, 1]
        ) else {
            colors.first?.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            return
        }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
    }

    private func drawCuteHandDrawn(_ image: UIImage, in canvasSize: CGSize) {
        let photoRect = CGRect(x: 120, y: 150, width: 840, height: 720)
        drawImage(image, aspectFillIn: photoRect, cornerRadius: 58)
        strokeRoundedRect(photoRect, cornerRadius: 58, color: UIColor.white.withAlphaComponent(0.92), width: 18)
        strokeRoundedRect(photoRect.insetBy(dx: -18, dy: -18), cornerRadius: 76, color: UIColor(red: 0.72, green: 0.25, blue: 0.38, alpha: 0.22), width: 10)
        drawSparkle(at: CGPoint(x: 180, y: 115), size: 44, color: UIColor(red: 0.72, green: 0.25, blue: 0.38, alpha: 0.72))
        drawSparkle(at: CGPoint(x: 910, y: 905), size: 58, color: UIColor(red: 0.95, green: 0.60, blue: 0.54, alpha: 0.70))
        drawCircle(at: CGPoint(x: 160, y: 925), radius: 20, color: UIColor(red: 0.46, green: 0.59, blue: 0.53, alpha: 0.34))
        drawCircle(at: CGPoint(x: 850, y: 115), radius: 28, color: UIColor(red: 0.95, green: 0.78, blue: 0.56, alpha: 0.48))
    }

    private func drawCover(_ image: UIImage, in canvasSize: CGSize) {
        drawImage(image, aspectFillIn: CGRect(origin: .zero, size: canvasSize), cornerRadius: 0, alpha: 0.28)

        let photoRect = CGRect(x: 86, y: 110, width: 908, height: 850)
        drawImage(image, aspectFillIn: photoRect, cornerRadius: 52)
        strokeRoundedRect(photoRect, cornerRadius: 52, color: UIColor.white.withAlphaComponent(0.90), width: 14)

        let panelRect = CGRect(x: 108, y: 1010, width: 864, height: 190)
        UIColor.white.withAlphaComponent(0.56).setFill()
        UIBezierPath(roundedRect: panelRect, cornerRadius: 42).fill()
        strokeRoundedRect(panelRect, cornerRadius: 42, color: UIColor.white.withAlphaComponent(0.88), width: 5)
        drawSparkle(at: CGPoint(x: 850, y: 1110), size: 46, color: UIColor(red: 0.72, green: 0.25, blue: 0.38, alpha: 0.62))
    }

    private func drawSticker(_ image: UIImage, in canvasSize: CGSize) {
        let stickerRect = CGRect(x: 145, y: 130, width: 790, height: 790)
        drawImage(image, aspectFillIn: stickerRect, cornerRadius: 132)
        strokeRoundedRect(stickerRect, cornerRadius: 132, color: UIColor.white, width: 30)
        strokeRoundedRect(stickerRect.insetBy(dx: -20, dy: -20), cornerRadius: 152, color: UIColor(red: 0.72, green: 0.25, blue: 0.38, alpha: 0.30), width: 10)

        for point in [
            CGPoint(x: 160, y: 160),
            CGPoint(x: 900, y: 170),
            CGPoint(x: 170, y: 900),
            CGPoint(x: 920, y: 850)
        ] {
            drawSparkle(at: point, size: 40, color: UIColor(red: 0.72, green: 0.25, blue: 0.38, alpha: 0.58))
        }

        drawCircle(at: CGPoint(x: 215, y: 780), radius: 16, color: UIColor(red: 0.95, green: 0.78, blue: 0.56, alpha: 0.74))
        drawCircle(at: CGPoint(x: 825, y: 760), radius: 22, color: UIColor(red: 0.46, green: 0.59, blue: 0.53, alpha: 0.42))
    }

    private func drawImage(
        _ image: UIImage,
        aspectFillIn rect: CGRect,
        cornerRadius: CGFloat,
        alpha: CGFloat = 1
    ) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        path.addClip()

        let imageSize = image.size
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: drawRect, blendMode: .normal, alpha: alpha)
        context.restoreGState()
    }

    private func strokeRoundedRect(_ rect: CGRect, cornerRadius: CGFloat, color: UIColor, width: CGFloat) {
        color.setStroke()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        path.lineWidth = width
        path.stroke()
    }

    private func drawCircle(at point: CGPoint, radius: CGFloat, color: UIColor) {
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)).fill()
    }

    private func drawSparkle(at point: CGPoint, size: CGFloat, color: UIColor) {
        color.setFill()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: point.x, y: point.y - size))
        path.addLine(to: CGPoint(x: point.x + size * 0.22, y: point.y - size * 0.22))
        path.addLine(to: CGPoint(x: point.x + size, y: point.y))
        path.addLine(to: CGPoint(x: point.x + size * 0.22, y: point.y + size * 0.22))
        path.addLine(to: CGPoint(x: point.x, y: point.y + size))
        path.addLine(to: CGPoint(x: point.x - size * 0.22, y: point.y + size * 0.22))
        path.addLine(to: CGPoint(x: point.x - size, y: point.y))
        path.addLine(to: CGPoint(x: point.x - size * 0.22, y: point.y - size * 0.22))
        path.close()
        path.fill()
    }
}

final class ShareCardRenderer {
    func render(
        image: UIImage,
        caption: String,
        template: ShareCardTemplate = ShareCardTemplateRepository().fallbackTemplate()
    ) -> UIImage {
        let palette = palette(for: template)
        let canvasWidth: CGFloat = 1080
        let horizontalPadding: CGFloat = 72
        let topPadding: CGFloat = 82
        let photoHeight: CGFloat = 710
        let contentWidth = canvasWidth - horizontalPadding * 2
        let captionInset: CGFloat = 54
        let captionWidth = contentWidth - captionInset * 2
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 10
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping

        var fontSize: CGFloat = 48
        var captionHeight = measuredCaptionHeight(
            caption,
            width: captionWidth,
            fontSize: fontSize,
            paragraphStyle: paragraphStyle
        )
        let maxPreferredCaptionHeight: CGFloat = 470
        while captionHeight > maxPreferredCaptionHeight && fontSize > 34 {
            fontSize -= 2
            captionHeight = measuredCaptionHeight(
                caption,
                width: captionWidth,
                fontSize: fontSize,
                paragraphStyle: paragraphStyle
            )
        }

        let panelVerticalInset: CGFloat = 46
        let panelHeight = max(260, captionHeight + panelVerticalInset * 2 + 38)
        let brandHeight: CGFloat = 58
        let canvasHeight = max(
            1350,
            topPadding + photoHeight + 44 + panelHeight + 40 + brandHeight + 70
        )
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { context in
            drawBackground(in: context.cgContext, size: canvasSize, template: template, palette: palette)

            let photoFrame = CGRect(
                x: horizontalPadding,
                y: topPadding,
                width: contentWidth,
                height: photoHeight
            )
            drawPhoto(image, in: photoFrame, template: template)

            let panelFrame = CGRect(
                x: horizontalPadding,
                y: photoFrame.maxY + 44,
                width: contentWidth,
                height: panelHeight
            )
            drawCaptionPanel(
                caption,
                in: panelFrame,
                captionInset: captionInset,
                fontSize: fontSize,
                paragraphStyle: paragraphStyle,
                template: template,
                palette: palette
            )

            drawBrand(at: CGPoint(x: canvasWidth / 2, y: panelFrame.maxY + 48), palette: palette)
        }
    }

    private func measuredCaptionHeight(
        _ caption: String,
        width: CGFloat,
        fontSize: CGFloat,
        paragraphStyle: NSParagraphStyle
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .paragraphStyle: paragraphStyle
        ]
        let rect = (caption as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(rect.height)
    }

    private func drawBackground(
        in context: CGContext,
        size: CGSize,
        template: ShareCardTemplate,
        palette: ShareCardPalette
    ) {
        let colors = palette.backgroundColors

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: [0, 0.56, 1]
        ) else {
            colors.first?.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            return
        }

        switch template {
        case .editorial:
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: 0),
                options: []
            )
        case .softBlush, .cleanWhite:
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }

    private func drawPhoto(_ image: UIImage, in frame: CGRect, template: ShareCardTemplate) {
        let outerCorner: CGFloat = template == .editorial ? 36 : 62
        let innerCorner: CGFloat = template == .editorial ? 30 : 58
        let imageCorner: CGFloat = template == .editorial ? 24 : 42

        let shadowPath = UIBezierPath(roundedRect: frame, cornerRadius: outerCorner)
        UIColor.black.withAlphaComponent(template == .editorial ? 0.14 : 0.08).setFill()
        shadowPath.fill()

        let container = frame.insetBy(dx: 10, dy: 10)
        UIColor.white.withAlphaComponent(0.92).setFill()
        UIBezierPath(roundedRect: container, cornerRadius: innerCorner).fill()

        let imageRect = aspectFitRect(for: image.size, in: container.insetBy(dx: 22, dy: 22))
        guard let context = UIGraphicsGetCurrentContext() else {
            image.draw(in: imageRect)
            return
        }

        context.saveGState()
        UIBezierPath(roundedRect: imageRect, cornerRadius: imageCorner).addClip()
        image.draw(in: imageRect)
        context.restoreGState()
    }

    private func drawCaptionPanel(
        _ caption: String,
        in frame: CGRect,
        captionInset: CGFloat,
        fontSize: CGFloat,
        paragraphStyle: NSParagraphStyle,
        template: ShareCardTemplate,
        palette: ShareCardPalette
    ) {
        let corner: CGFloat = template == .editorial ? 38 : 54
        palette.panelColor.setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: corner).fill()
        palette.borderColor.setStroke()
        let borderPath = UIBezierPath(roundedRect: frame, cornerRadius: corner)
        borderPath.lineWidth = template == .editorial ? 2 : 3
        borderPath.stroke()

        let markColor = palette.accentColor
        markColor.setFill()
        let quoteAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 54, weight: .bold),
            .foregroundColor: markColor
        ]
        "“".draw(
            at: CGPoint(x: frame.minX + captionInset, y: frame.minY + 24),
            withAttributes: quoteAttributes
        )

        let textRect = CGRect(
            x: frame.minX + captionInset,
            y: frame.minY + 74,
            width: frame.width - captionInset * 2,
            height: frame.height - 112
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: palette.textColor,
            .paragraphStyle: paragraphStyle
        ]
        (caption as NSString).draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }

    private func drawBrand(at point: CGPoint, palette: ShareCardPalette) {
        let title = "SnapCopy"
        let logoSize: CGFloat = 68
        let spacing: CGFloat = 18
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
            .foregroundColor: palette.brandColor
        ]
        let textSize = (title as NSString).size(withAttributes: attributes)
        let totalWidth = logoSize + spacing + textSize.width
        let logoFrame = CGRect(
            x: point.x - totalWidth / 2,
            y: point.y,
            width: logoSize,
            height: logoSize
        )
        drawLogo(in: logoFrame, borderColor: palette.borderColor)
        (title as NSString).draw(
            at: CGPoint(
                x: logoFrame.maxX + spacing,
                y: point.y + (logoSize - textSize.height) / 2
            ),
            withAttributes: attributes
        )
    }

    private func drawLogo(in frame: CGRect, borderColor: UIColor) {
        let circlePath = UIBezierPath(ovalIn: frame)
        UIColor.white.withAlphaComponent(0.94).setFill()
        circlePath.fill()
        borderColor.setStroke()
        circlePath.lineWidth = 2
        circlePath.stroke()

        guard let logo = UIImage(named: "ShareCardLogo"),
              let context = UIGraphicsGetCurrentContext()
        else {
            return
        }

        let imageRect = aspectFillRect(for: logo.size, in: frame.insetBy(dx: 4, dy: 4))
        context.saveGState()
        UIBezierPath(ovalIn: frame.insetBy(dx: 4, dy: 4)).addClip()
        logo.draw(in: imageRect)
        context.restoreGState()
    }

    private func palette(for template: ShareCardTemplate) -> ShareCardPalette {
        switch template {
        case .softBlush:
            return ShareCardPalette(
                backgroundColors: [
                    UIColor(red: 1.00, green: 0.96, blue: 0.97, alpha: 1),
                    UIColor(red: 0.96, green: 0.99, blue: 0.96, alpha: 1),
                    UIColor(red: 1.00, green: 0.94, blue: 0.92, alpha: 1)
                ],
                panelColor: UIColor.white.withAlphaComponent(0.84),
                borderColor: UIColor(red: 0.72, green: 0.25, blue: 0.38, alpha: 0.16),
                accentColor: UIColor(red: 0.72, green: 0.25, blue: 0.38, alpha: 0.72),
                textColor: UIColor(red: 0.16, green: 0.13, blue: 0.20, alpha: 1),
                brandColor: UIColor(red: 0.72, green: 0.25, blue: 0.38, alpha: 0.72)
            )
        case .cleanWhite:
            return ShareCardPalette(
                backgroundColors: [
                    UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1),
                    UIColor(red: 0.95, green: 0.98, blue: 0.97, alpha: 1),
                    UIColor(red: 0.98, green: 0.96, blue: 0.98, alpha: 1)
                ],
                panelColor: UIColor.white.withAlphaComponent(0.9),
                borderColor: UIColor(red: 0.44, green: 0.55, blue: 0.50, alpha: 0.18),
                accentColor: UIColor(red: 0.36, green: 0.50, blue: 0.45, alpha: 0.7),
                textColor: UIColor(red: 0.13, green: 0.16, blue: 0.18, alpha: 1),
                brandColor: UIColor(red: 0.36, green: 0.50, blue: 0.45, alpha: 0.72)
            )
        case .editorial:
            return ShareCardPalette(
                backgroundColors: [
                    UIColor(red: 0.13, green: 0.11, blue: 0.14, alpha: 1),
                    UIColor(red: 0.25, green: 0.18, blue: 0.22, alpha: 1),
                    UIColor(red: 0.96, green: 0.92, blue: 0.87, alpha: 1)
                ],
                panelColor: UIColor(red: 0.98, green: 0.94, blue: 0.89, alpha: 0.96),
                borderColor: UIColor(red: 0.93, green: 0.76, blue: 0.62, alpha: 0.34),
                accentColor: UIColor(red: 0.68, green: 0.22, blue: 0.35, alpha: 0.74),
                textColor: UIColor(red: 0.13, green: 0.10, blue: 0.13, alpha: 1),
                brandColor: UIColor(red: 0.93, green: 0.76, blue: 0.62, alpha: 0.82)
            )
        }
    }

    private func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - drawSize.width / 2,
            y: bounds.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    private func aspectFillRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return bounds
        }

        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - drawSize.width / 2,
            y: bounds.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }
}

private struct ShareCardPalette {
    let backgroundColors: [UIColor]
    let panelColor: UIColor
    let borderColor: UIColor
    let accentColor: UIColor
    let textColor: UIColor
    let brandColor: UIColor
}

protocol CloudCreativeImageGenerating {
    var isConfigured: Bool { get }

    func generateImage(
        from sourceImage: UIImage,
        style: CreativeImageStyle,
        context: CaptionGenerationContext
    ) async throws -> UIImage
}

final class CloudCreativeImageService: CloudCreativeImageGenerating {
    var isConfigured: Bool {
        false
    }

    func generateImage(
        from sourceImage: UIImage,
        style: CreativeImageStyle,
        context: CaptionGenerationContext
    ) async throws -> UIImage {
        throw CreativeImageGenerationError.cloudNotConfigured
    }
}

private extension UIImage {
    var normalizedCGImage: CGImage? {
        if imageOrientation == .up, let cgImage {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let renderedImage = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }

        return renderedImage.cgImage
    }
}
