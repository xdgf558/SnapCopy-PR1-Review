import Foundation

enum CaptionGenerationMode: String, Codable {
    case mock
    case localAI
    case cloudEnhanced

    var displayName: String {
        switch self {
        case .mock:
            "基础文案"
        case .localAI:
            "本机 AI"
        case .cloudEnhanced:
            "云端增强"
        }
    }
}

struct CaptionGenerationResult {
    let candidates: [CaptionCandidate]
    let mode: CaptionGenerationMode
    let statusMessage: String
    let debugInfo: CaptionGenerationDebugInfo?
}

struct CaptionGenerationDebugInfo {
    let contextJSON: String
    let foundationPrompt: String
    let rawFoundationResult: String
}

enum LocalAIAvailabilityStatus: Equatable {
    case available
    case unavailable(String)

    var displayName: String {
        switch self {
        case .available:
            "本机 AI 可用"
        case .unavailable:
            "本机 AI 不可用"
        }
    }

    var detail: String {
        switch self {
        case .available:
            "将优先使用 Apple Foundation Models。"
        case .unavailable(let reason):
            reason
        }
    }
}
