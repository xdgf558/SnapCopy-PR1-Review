import Foundation

enum TrainingContributionKind: String, Codable {
    case photo
    case caption
}

enum TrainingContributionSource: String, Codable {
    case cloudEnhancement
    case share
    case copy
    case manual
}

enum TrainingContributionDecision: String, Codable {
    case granted
    case declined
}

enum TrainingContributionConstants {
    static let privacyPolicyVersion = "snapcopy-beta-privacy-v1"
    static let photoContributionScope = "anonymous_photo_scene_metadata_only"
    static let captionContributionScope = "anonymous_final_caption_sample"
    static let metadataOnlyRetention = "not_uploaded_metadata_only"
}

struct TrainingContributionConsentRequest: Codable, Equatable {
    let appUserId: UUID
    let consentId: UUID
    let kind: TrainingContributionKind
    let decision: TrainingContributionDecision
    let scope: String
    let privacyPolicyVersion: String
    let locale: String
    let createdAt: Date
}

struct TrainingContributionSampleRequest: Codable, Equatable {
    let appUserId: UUID
    let consentId: UUID
    let sampleId: UUID
    let kind: TrainingContributionKind
    let source: TrainingContributionSource
    let consentGranted: Bool
    let privacyPolicyVersion: String
    let locale: String
    let targetPlatform: SocialPlatform?
    let scene: String?
    let sceneConfidence: Double?
    let sceneTags: [String]
    let sceneJson: String?
    let captionText: String?
    let captionWasEdited: Bool
    let imageUploadEnabled: Bool
    let originalPhotoRetention: String
    let createdAt: Date
    let notes: String?
}

struct TrainingContributionResponse: Codable, Equatable {
    let accepted: Bool
    let consentId: UUID
    let sampleId: UUID?
    let storageMode: String
    let retentionPolicy: String
    let message: String
}

struct TrainingContributionLocalRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let appUserId: UUID
    let consentId: UUID
    let sampleId: UUID?
    let kind: TrainingContributionKind
    let source: TrainingContributionSource
    let decision: TrainingContributionDecision
    let scene: String?
    let targetPlatform: SocialPlatform?
    let storageMode: String
    let createdAt: Date
}

struct TrainingContributionPrompt: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let confirmTitle: String
    let declineTitle: String
    let consentRequest: TrainingContributionConsentRequest
    let sampleRequest: TrainingContributionSampleRequest
}
