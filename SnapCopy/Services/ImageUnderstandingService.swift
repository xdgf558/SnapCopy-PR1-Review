import ImageIO
import UIKit
import Vision

final class ImageUnderstandingService {
    private let imageAnalyzer = ImageAnalyzer()

    func analyze(_ image: UIImage) async -> ImageUnderstandingResult {
        await imageAnalyzer.analyze(image).understandingResult
    }
}

enum ImageVisualAnalyzer {
    static func visualTraits(from cgImage: CGImage, imageSize: CGSize) -> ImageVisualTraits {
        let sampleWidth = 24
        let sampleHeight = 24
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let didDraw = rawData.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
            return true
        }

        guard didDraw else {
            return .empty
        }

        var brightnessValues: [Double] = []
        var saturationValues: [Double] = []
        var redTotal = 0.0
        var blueTotal = 0.0
        var colorCounts: [String: Int] = [:]

        for index in stride(from: 0, to: rawData.count, by: bytesPerPixel) {
            let red = Double(rawData[index]) / 255.0
            let green = Double(rawData[index + 1]) / 255.0
            let blue = Double(rawData[index + 2]) / 255.0
            let brightness = 0.299 * red + 0.587 * green + 0.114 * blue
            let saturation = saturation(red: red, green: green, blue: blue)

            brightnessValues.append(brightness)
            saturationValues.append(saturation)
            redTotal += red
            blueTotal += blue

            let colorName = dominantColorName(red: red, green: green, blue: blue, brightness: brightness, saturation: saturation)
            colorCounts[colorName, default: 0] += 1
        }

        let averageBrightness = average(brightnessValues)
        let averageSaturation = average(saturationValues)
        let colorTemperature = colorTemperature(redTotal: redTotal, blueTotal: blueTotal, pixelCount: brightnessValues.count)
        let dominantColors = colorCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }

                return lhs.value > rhs.value
            }
            .prefix(4)
            .map(\.key)

        return ImageVisualTraits(
            brightness: brightnessCategory(averageBrightness),
            colorTemperature: colorTemperature,
            saturation: saturationCategory(averageSaturation),
            aspect: aspectCategory(imageSize),
            dominantColors: dominantColors
        )
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        return values.reduce(0, +) / Double(values.count)
    }

    private static func saturation(red: Double, green: Double, blue: Double) -> Double {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)

        guard maxValue > 0 else {
            return 0
        }

        return (maxValue - minValue) / maxValue
    }

    private static func brightnessCategory(_ value: Double) -> ImageBrightness {
        switch value {
        case ..<0.25:
            return .dark
        case ..<0.43:
            return .dim
        case ..<0.72:
            return .balanced
        default:
            return .bright
        }
    }

    private static func saturationCategory(_ value: Double) -> ImageSaturation {
        switch value {
        case ..<0.18:
            return .muted
        case ..<0.42:
            return .natural
        default:
            return .vivid
        }
    }

    private static func colorTemperature(redTotal: Double, blueTotal: Double, pixelCount: Int) -> ImageColorTemperature {
        guard pixelCount > 0 else {
            return .unknown
        }

        let difference = (redTotal - blueTotal) / Double(pixelCount)

        if difference > 0.06 {
            return .warm
        }

        if difference < -0.06 {
            return .cool
        }

        return .neutral
    }

    private static func aspectCategory(_ size: CGSize) -> ImageAspect {
        guard size.width > 0, size.height > 0 else {
            return .unknown
        }

        let ratio = size.width / size.height

        if ratio > 1.15 {
            return .landscape
        }

        if ratio < 0.85 {
            return .portrait
        }

        return .square
    }

    private static func dominantColorName(
        red: Double,
        green: Double,
        blue: Double,
        brightness: Double,
        saturation: Double
    ) -> String {
        if brightness < 0.18 {
            return "dark"
        }

        if brightness > 0.82, saturation < 0.18 {
            return "light"
        }

        if saturation < 0.14 {
            return "neutral"
        }

        let hue = hueDegrees(red: red, green: green, blue: blue)

        switch hue {
        case 0..<22, 340...360:
            return "red"
        case 22..<45:
            return "orange"
        case 45..<70:
            return "yellow"
        case 70..<165:
            return "green"
        case 165..<205:
            return "cyan"
        case 205..<260:
            return "blue"
        case 260..<300:
            return "purple"
        default:
            return "pink"
        }
    }

    private static func hueDegrees(red: Double, green: Double, blue: Double) -> Double {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue

        guard delta > 0 else {
            return 0
        }

        let hue: Double

        if maxValue == red {
            hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == green {
            hue = 60 * (((blue - red) / delta) + 2)
        } else {
            hue = 60 * (((red - green) / delta) + 4)
        }

        return hue < 0 ? hue + 360 : hue
    }
}

enum ImageSceneMapper {
    static func sceneTags(from labels: [String]) -> [String] {
        var tags: [String] = []

        for label in labels.map({ $0.lowercased() }) {
            appendFoodTags(from: label, to: &tags)
            appendPetTags(from: label, to: &tags)
            appendTravelTags(from: label, to: &tags)
            appendStreetTags(from: label, to: &tags)
            appendWorkTags(from: label, to: &tags)
            appendOutfitTags(from: label, to: &tags)
            appendWorkoutTags(from: label, to: &tags)
        }

        return unique(tags).prefix(5).map { $0 }
    }

    private static func appendFoodTags(from label: String, to tags: inout [String]) {
        if contains(label, ["breakfast", "brunch", "早餐"]) {
            tags.append(contentsOf: ["breakfast", "food", "morning"])
        } else if contains(label, ["coffee", "espresso", "latte", "cappuccino", "drink", "cup", "咖啡", "杯"]) {
            tags.append(contentsOf: ["coffee", "drink", "daily"])
        } else if contains(label, ["food", "meal", "dish", "dessert", "cake", "restaurant", "cuisine", "plate", "bowl", "tableware", "utensil", "fork", "knife", "美食", "餐", "饭", "菜"]) {
            tags.append(contentsOf: ["food", "daily"])
        }
    }

    private static func appendPetTags(from label: String, to tags: inout [String]) {
        if contains(label, ["dog", "cat", "pet", "animal", "puppy", "kitten", "canine", "feline", "猫", "狗", "宠物"]) {
            tags.append(contentsOf: ["pet", "daily"])
        }
    }

    private static func appendTravelTags(from label: String, to tags: inout [String]) {
        if contains(label, ["travel", "trip", "beach", "ocean", "sea", "mountain", "landscape", "landmark", "airport", "hotel", "train", "vacation"]) {
            tags.append(contentsOf: ["travel", "landscape", "outdoor"])
        }
    }

    private static func appendStreetTags(from label: String, to tags: inout [String]) {
        if contains(label, ["street", "city", "urban", "building", "architecture", "road", "sidewalk", "skyline"]) {
            tags.append(contentsOf: ["street", "city", "daily"])
        }
    }

    private static func appendWorkTags(from label: String, to tags: inout [String]) {
        if contains(label, ["office", "desk", "laptop", "computer", "keyboard", "notebook", "book", "work", "document", "monitor", "screen", "meeting", "calendar", "email", "办公", "工作", "电脑", "会议", "日程", "笔记"]) {
            tags.append(contentsOf: ["work", "desk", "daily"])
        }
    }

    private static func appendOutfitTags(from label: String, to tags: inout [String]) {
        if contains(label, ["outfit", "fashion", "clothing", "dress", "shoe", "bag", "person"]) {
            tags.append(contentsOf: ["outfit", "fashion", "daily"])
        }
    }

    private static func appendWorkoutTags(from label: String, to tags: inout [String]) {
        if contains(label, ["fitness", "workout", "gym", "running", "yoga", "exercise", "sport"]) {
            tags.append(contentsOf: ["workout", "fitness", "daily"])
        }
    }

    private static func contains(_ label: String, _ keywords: [String]) -> Bool {
        keywords.contains { keyword in
            label.contains(keyword)
        }
    }

    private static func unique(_ tags: [String]) -> [String] {
        var seen: Set<String> = []

        return tags.filter { tag in
            if seen.contains(tag) {
                return false
            }

            seen.insert(tag)
            return true
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
