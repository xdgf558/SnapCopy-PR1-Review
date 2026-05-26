import Foundation

enum CloudProvider: String, Codable, CaseIterable, Identifiable {
    case disabled
    case mock
    case gemini
    case qwen
    case glm
    case ppq

    var id: String { rawValue }
}

enum CloudEnhancementFeatureType: String, Codable, CaseIterable, Identifiable {
    case captionDeepUnderstanding
    case imageUnderstanding
    case creativeShareImage
    case coverImage
    case stickerImage

    var id: String { rawValue }
}

struct CloudEnhancementConfig: Codable, Equatable {
    var enabled: Bool
    var provider: CloudProvider
    var endpoint: URL?
    var timeoutSeconds: Double
    var maxImageUploadBytes: Int
    var privacyNoticeRequired: Bool

    static let disabled = CloudEnhancementConfig(
        enabled: false,
        provider: .disabled,
        endpoint: nil,
        timeoutSeconds: 35,
        maxImageUploadBytes: 0,
        privacyNoticeRequired: true
    )

    static let mockBeta = CloudEnhancementConfig(
        enabled: true,
        provider: .mock,
        endpoint: URL(string: "https://snapcopy-cloud-api.yehao1105.workers.dev"),
        timeoutSeconds: 35,
        maxImageUploadBytes: 1_500_000,
        privacyNoticeRequired: true
    )
}

enum CloudFeatureFlags {
    // Keep cloud enhancement available in TestFlight beta builds. Before public App Store release,
    // move this behind remote config or StoreKit entitlement checks.
    static let cloudEnhancedCaptions = true

    static let cloudImageUnderstanding = true
    static let cloudEnhancedDebugMode = false

    static let betaCloudTestUser = true
}

struct CloudEnhancementRequest: Codable, Equatable {
    let appUserId: UUID
    let requestId: UUID
    let plan: EntitlementLevel
    let clientAppVersion: String
    let clientBuild: String
    let featureType: CloudEnhancementFeatureType
    let sceneJson: String
    let userPreferenceJson: String?
    let imageUploadEnabled: Bool
    let locale: String
    let targetPlatform: SocialPlatform
}

struct CloudEnhancementResponse: Codable, Equatable {
    let captions: [String]
    let provider: String
    let model: String
    let inputTokens: Int?
    let outputTokens: Int?
    let estimatedCost: Double?
    let remainingQuota: Int?
}

struct CloudImageUnderstandingRequest: Codable, Equatable {
    let appUserId: UUID
    let requestId: UUID
    let plan: EntitlementLevel
    let clientAppVersion: String
    let clientBuild: String
    let featureType: CloudEnhancementFeatureType
    let sceneJson: String?
    let userPreferenceJson: String?
    let imageUploadEnabled: Bool
    let imageBase64: String
    let imageMimeType: String
    let locale: String
    let targetPlatform: SocialPlatform
}

struct CloudSceneCandidate: Codable, Equatable {
    let scene: String
    let confidence: Double
    let reason: String?
}

struct CloudVisionUnderstanding: Codable, Equatable {
    let scene: String
    let subScene: String?
    let confidence: Double
    let top3Scenes: [CloudSceneCandidate]
    let sceneTags: [String]
    let captionFocus: String?
    let semanticSummary: String?
    let subjectCues: [String]
    let objectCues: [String]
    let actionCues: [String]
    let relationshipCues: [String]
    let atmosphereCues: [String]
    let ocrTexts: [String]
    let mustMentionCues: [String]
    let avoidUnsupportedClaims: [String]
}

struct CloudImageUnderstandingResponse: Codable, Equatable {
    let understanding: CloudVisionUnderstanding
    let sceneJson: String
    let provider: String
    let model: String
    let inputTokens: Int?
    let outputTokens: Int?
    let estimatedCost: Double?
    let remainingQuota: Int?
}

struct UsageStatus: Codable, Equatable {
    let plan: EntitlementLevel
    let dailyLimit: Int
    let usedToday: Int
    let remainingQuota: Int
}

struct CloudPreferenceSnapshot: Codable, Equatable {
    let preferredStyles: [String]
    let avoidStyles: [String]
    let likedPhrases: [String]
    let avoidPhrases: [String]
    let preferredLengthLevel: LengthLevel
    let preferredLanguage: CaptionLanguage
    let preferredPlatforms: [SocialPlatform]
    let sentenceShape: String?
    let emojiPreference: String?
    let punctuationPreference: String?
}

enum CloudEnhancementError: Error, Equatable {
    case disabled
    case quotaExceeded
    case invalidResponse
    case requestFailed(String)
}

extension CloudEnhancementError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .disabled:
            "Cloud enhancement is disabled."
        case .quotaExceeded:
            "Cloud enhancement quota exceeded."
        case .invalidResponse:
            "Cloud enhancement returned an invalid response."
        case .requestFailed(let message):
            "Cloud enhancement request failed: \(message)"
        }
    }
}

struct CloudEnhancementRequestBuilder {
    func makeRequest(
        appUserId: UUID,
        requestId: UUID = UUID(),
        plan: EntitlementLevel,
        clientAppVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        clientBuild: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
        featureType: CloudEnhancementFeatureType,
        sceneJson: String,
        userPreferenceJson: String? = nil,
        imageUploadEnabled: Bool,
        locale: String,
        targetPlatform: SocialPlatform
    ) -> CloudEnhancementRequest {
        CloudEnhancementRequest(
            appUserId: appUserId,
            requestId: requestId,
            plan: plan,
            clientAppVersion: clientAppVersion,
            clientBuild: clientBuild,
            featureType: featureType,
            sceneJson: sceneJson,
            userPreferenceJson: userPreferenceJson,
            imageUploadEnabled: imageUploadEnabled,
            locale: locale,
            targetPlatform: targetPlatform
        )
    }

    func makeImageUnderstandingRequest(
        appUserId: UUID,
        requestId: UUID = UUID(),
        plan: EntitlementLevel,
        clientAppVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        clientBuild: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
        sceneJson: String?,
        userPreferenceJson: String? = nil,
        imageBase64: String,
        imageMimeType: String = "image/jpeg",
        locale: String,
        targetPlatform: SocialPlatform
    ) -> CloudImageUnderstandingRequest {
        CloudImageUnderstandingRequest(
            appUserId: appUserId,
            requestId: requestId,
            plan: plan,
            clientAppVersion: clientAppVersion,
            clientBuild: clientBuild,
            featureType: .imageUnderstanding,
            sceneJson: sceneJson,
            userPreferenceJson: userPreferenceJson,
            imageUploadEnabled: true,
            imageBase64: imageBase64,
            imageMimeType: imageMimeType,
            locale: locale,
            targetPlatform: targetPlatform
        )
    }
}
