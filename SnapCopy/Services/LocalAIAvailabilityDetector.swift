import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct LocalAIAvailabilityDetector {
    static func currentStatus() -> LocalAIAvailabilityStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return foundationModelsStatus()
        } else {
            return .unavailable("需要 iOS 26 或更高版本。")
        }
        #else
        return .unavailable("当前 Xcode SDK 不包含 Foundation Models。")
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func foundationModelsStatus() -> LocalAIAvailabilityStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable("当前设备不支持 Apple Intelligence。")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("请在系统设置里开启 Apple Intelligence。")
        case .unavailable(.modelNotReady):
            return .unavailable("本机模型还没准备好，可能仍在下载。")
        case .unavailable:
            return .unavailable("本机 AI 暂不可用。")
        }
    }
    #endif
}
