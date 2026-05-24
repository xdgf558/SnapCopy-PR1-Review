import Foundation

struct ImageUnderstandingResult: Equatable {
    let sceneTags: [String]
    let detectedLabels: [ImageUnderstandingLabel]
    let detectedTexts: [String]
    let visualTraits: ImageVisualTraits

    init(
        sceneTags: [String],
        detectedLabels: [ImageUnderstandingLabel],
        detectedTexts: [String] = [],
        visualTraits: ImageVisualTraits = .empty
    ) {
        self.sceneTags = sceneTags
        self.detectedLabels = detectedLabels
        self.detectedTexts = detectedTexts
        self.visualTraits = visualTraits
    }

    static let empty = ImageUnderstandingResult(sceneTags: [], detectedLabels: [], detectedTexts: [], visualTraits: .empty)

    var hasUsefulTags: Bool {
        !sceneTags.isEmpty
    }

    var hasUsefulContext: Bool {
        hasUsefulTags || !detectedLabels.isEmpty || !detectedTexts.isEmpty || visualTraits.hasUsefulContext
    }

    var promptDescription: String? {
        var parts: [String] = []

        let labels = detectedLabels
            .prefix(8)
            .map(\.name)
            .joined(separator: ", ")

        if !labels.isEmpty {
            parts.append("Vision labels: \(labels)")
        }

        let texts = detectedTexts
            .prefix(4)
            .joined(separator: " / ")

        if !texts.isEmpty {
            parts.append("Visible text OCR: \(texts)")
        }

        if let visualSummary = visualTraits.promptSummary {
            parts.append("Visual traits: \(visualSummary)")
        }

        if parts.isEmpty {
            return nil
        }

        return parts.joined(separator: "\n")
    }

    var statusSummary: String? {
        var fragments: [String] = []

        if !detectedTexts.isEmpty {
            fragments.append("文字：\(detectedTexts.prefix(2).joined(separator: "、"))")
        }

        if let visualSummary = visualTraits.statusSummary {
            fragments.append(visualSummary)
        }

        guard !fragments.isEmpty else {
            return nil
        }

        return fragments.joined(separator: "；")
    }
}

struct ImageUnderstandingLabel: Equatable {
    let name: String
    let confidence: Double
}

struct ImageVisualTraits: Equatable {
    let brightness: ImageBrightness
    let colorTemperature: ImageColorTemperature
    let saturation: ImageSaturation
    let aspect: ImageAspect
    let dominantColors: [String]

    static let empty = ImageVisualTraits(
        brightness: .unknown,
        colorTemperature: .unknown,
        saturation: .unknown,
        aspect: .unknown,
        dominantColors: []
    )

    var hasUsefulContext: Bool {
        brightness != .unknown ||
        colorTemperature != .unknown ||
        saturation != .unknown ||
        aspect != .unknown ||
        !dominantColors.isEmpty
    }

    var promptSummary: String? {
        guard hasUsefulContext else {
            return nil
        }

        var parts: [String] = []

        if brightness != .unknown {
            parts.append("brightness=\(brightness.rawValue)")
        }

        if colorTemperature != .unknown {
            parts.append("colorTemperature=\(colorTemperature.rawValue)")
        }

        if saturation != .unknown {
            parts.append("colorSaturation=\(saturation.rawValue)")
        }

        if aspect != .unknown {
            parts.append("framing=\(aspect.rawValue)")
        }

        if !dominantColors.isEmpty {
            parts.append("dominantColors=\(dominantColors.joined(separator: ", "))")
        }

        return parts.joined(separator: ", ")
    }

    var statusSummary: String? {
        guard hasUsefulContext else {
            return nil
        }

        var parts: [String] = []

        if brightness != .unknown {
            parts.append(brightness.displayName)
        }

        if colorTemperature != .unknown {
            parts.append(colorTemperature.displayName)
        }

        if saturation != .unknown {
            parts.append(saturation.displayName)
        }

        if aspect != .unknown {
            parts.append(aspect.displayName)
        }

        if !dominantColors.isEmpty {
            parts.append(dominantColors.prefix(3).joined(separator: "、"))
        }

        return parts.joined(separator: "、")
    }
}

enum ImageBrightness: String {
    case dark
    case dim
    case balanced
    case bright
    case unknown

    var displayName: String {
        switch self {
        case .dark:
            "暗调"
        case .dim:
            "低光"
        case .balanced:
            "光线均衡"
        case .bright:
            "明亮"
        case .unknown:
            "光线未知"
        }
    }
}

enum ImageColorTemperature: String {
    case warm
    case neutral
    case cool
    case unknown

    var displayName: String {
        switch self {
        case .warm:
            "暖色"
        case .neutral:
            "自然色"
        case .cool:
            "冷色"
        case .unknown:
            "色温未知"
        }
    }
}

enum ImageSaturation: String {
    case muted
    case natural
    case vivid
    case unknown

    var displayName: String {
        switch self {
        case .muted:
            "低饱和"
        case .natural:
            "自然饱和"
        case .vivid:
            "高饱和"
        case .unknown:
            "饱和度未知"
        }
    }
}

enum ImageAspect: String {
    case portrait
    case landscape
    case square
    case unknown

    var displayName: String {
        switch self {
        case .portrait:
            "竖图"
        case .landscape:
            "横图"
        case .square:
            "方图"
        case .unknown:
            "画幅未知"
        }
    }
}

enum ManualSceneOption: String, CaseIterable, Identifiable {
    case auto
    case breakfast
    case coffee
    case walk
    case travel
    case outfit
    case pet
    case workout
    case street
    case food
    case work
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            "自动识别"
        case .breakfast:
            "早餐"
        case .coffee:
            "咖啡"
        case .walk:
            "散步"
        case .travel:
            "旅行"
        case .outfit:
            "穿搭"
        case .pet:
            "宠物"
        case .workout:
            "运动"
        case .street:
            "街景"
        case .food:
            "美食"
        case .work:
            "工作"
        case .other:
            "日常"
        }
    }

    var sceneTags: [String] {
        switch self {
        case .auto:
            []
        case .breakfast:
            ["breakfast", "food", "morning"]
        case .coffee:
            ["coffee", "drink", "daily"]
        case .walk:
            ["walk", "daily", "outdoor"]
        case .travel:
            ["travel", "landscape", "outdoor"]
        case .outfit:
            ["outfit", "fashion", "daily"]
        case .pet:
            ["pet", "daily"]
        case .workout:
            ["workout", "fitness", "daily"]
        case .street:
            ["street", "city", "daily"]
        case .food:
            ["food", "daily"]
        case .work:
            ["work", "desk", "daily"]
        case .other:
            ["daily"]
        }
    }
}
