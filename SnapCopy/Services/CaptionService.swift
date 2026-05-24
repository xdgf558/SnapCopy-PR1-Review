import UIKit

protocol CaptionService {
    func localAIStatus() -> LocalAIAvailabilityStatus
    func generateCaptions(
        for image: UIImage,
        context: CaptionGenerationContext,
        preference: UserPreference
    ) async throws -> CaptionGenerationResult
}
