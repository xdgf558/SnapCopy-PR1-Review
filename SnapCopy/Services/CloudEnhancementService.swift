import Foundation

final class CloudEnhancementService {
    private let config: CloudEnhancementConfig
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        config: CloudEnhancementConfig = CloudFeatureFlags.cloudEnhancedCaptions ? .mockBeta : .disabled,
        session: URLSession = .shared
    ) {
        self.config = config
        self.session = session
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    var isEnabled: Bool {
        config.enabled && config.provider != .disabled
    }

    var endpointDescription: String {
        config.endpoint?.absoluteString ?? "local-mock"
    }

    var providerDescription: String {
        config.provider.rawValue
    }

    func enhanceCaptions(request: CloudEnhancementRequest) async throws -> CloudEnhancementResponse {
        guard isEnabled else {
            throw CloudEnhancementError.disabled
        }

        guard !request.imageUploadEnabled else {
            throw CloudEnhancementError.requestFailed("Image upload is not enabled in this build.")
        }

        guard let endpoint = config.endpoint else {
            return mockResponse(for: request)
        }

        return try await postCaptionRequest(request, endpoint: endpoint)
    }

    func enhanceImageUnderstanding(request: CloudImageUnderstandingRequest) async throws -> CloudImageUnderstandingResponse {
        guard isEnabled else {
            throw CloudEnhancementError.disabled
        }

        guard request.imageUploadEnabled else {
            throw CloudEnhancementError.requestFailed("Image upload is required for cloud image understanding.")
        }

        guard request.imageBase64.utf8.count <= max(1, config.maxImageUploadBytes) || config.maxImageUploadBytes == 0 else {
            throw CloudEnhancementError.requestFailed("Image payload is too large for cloud understanding.")
        }

        guard let endpoint = config.endpoint else {
            throw CloudEnhancementError.disabled
        }

        return try await postVisionRequest(request, endpoint: endpoint)
    }

    func usageStatus(appUserId: UUID, plan: EntitlementLevel, usedToday: Int, isTestUser: Bool) -> UsageStatus {
        let dailyLimit = plan.dailyCloudEnhancementLimit(isTestUser: isTestUser)
        return UsageStatus(
            plan: plan,
            dailyLimit: dailyLimit,
            usedToday: usedToday,
            remainingQuota: max(0, dailyLimit - usedToday)
        )
    }

    private func postCaptionRequest(
        _ request: CloudEnhancementRequest,
        endpoint: URL
    ) async throws -> CloudEnhancementResponse {
        let url = endpoint.appendingPathComponent("api/cloud-enhance/caption")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("SnapCopy-iOS-Debug", forHTTPHeaderField: "X-SnapCopy-App")
        urlRequest.httpBody = try encoder.encode(request)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudEnhancementError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let errorMessage = cloudErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                if httpResponse.statusCode == 429 {
                    throw CloudEnhancementError.quotaExceeded
                }

                throw CloudEnhancementError.requestFailed(errorMessage)
            }

            let cloudResponse = try decoder.decode(CloudEnhancementResponse.self, from: data)
            guard !cloudResponse.captions.isEmpty else {
                throw CloudEnhancementError.invalidResponse
            }

            return cloudResponse
        } catch let error as CloudEnhancementError {
            throw error
        } catch {
            throw CloudEnhancementError.requestFailed(error.localizedDescription)
        }
    }

    private func postVisionRequest(
        _ request: CloudImageUnderstandingRequest,
        endpoint: URL
    ) async throws -> CloudImageUnderstandingResponse {
        let url = endpoint.appendingPathComponent("api/cloud-enhance/vision")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("SnapCopy-iOS-Debug", forHTTPHeaderField: "X-SnapCopy-App")
        urlRequest.httpBody = try encoder.encode(request)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloudEnhancementError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let errorMessage = cloudErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                if httpResponse.statusCode == 429 {
                    throw CloudEnhancementError.quotaExceeded
                }

                throw CloudEnhancementError.requestFailed(errorMessage)
            }

            let cloudResponse = try decoder.decode(CloudImageUnderstandingResponse.self, from: data)
            guard !cloudResponse.sceneJson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CloudEnhancementError.invalidResponse
            }

            return cloudResponse
        } catch let error as CloudEnhancementError {
            throw error
        } catch {
            throw CloudEnhancementError.requestFailed(error.localizedDescription)
        }
    }

    private func cloudErrorMessage(from data: Data) -> String? {
        guard let envelope = try? decoder.decode(CloudErrorEnvelope.self, from: data) else {
            return nil
        }

        return "\(envelope.error.code): \(envelope.error.message)"
    }

    private func mockResponse(for request: CloudEnhancementRequest) -> CloudEnhancementResponse {
        let lowercasedContext = request.sceneJson.lowercased()
        let captions: [String]

        if lowercasedContext.contains("cafe") || lowercasedContext.contains("coffee") {
            captions = [
                "把节奏先放慢一点，今天从这杯咖啡开始。",
                "咖啡在手，忙碌也可以有一点松弛。",
                "给自己留一段不被打扰的咖啡时间。",
                "这一口，是今天的小小缓冲区。",
                "先坐下来，再和今天慢慢交手。"
            ]
        } else if lowercasedContext.contains("pet") || lowercasedContext.contains("cat") || lowercasedContext.contains("dog") {
            captions = [
                "它只是出现一下，生活就变得有表情了。",
                "今天的主角很清楚自己有多会抢镜。",
                "有些陪伴不用说话，也很有存在感。",
                "这一幕很日常，但刚好让人想留下。",
                "被它看一眼，今天就自动柔软一点。"
            ]
        } else if lowercasedContext.contains("food") || lowercasedContext.contains("breakfast") {
            captions = [
                "认真吃饭，也是把今天照顾好的一种方式。",
                "这一餐不负责隆重，只负责把人安顿下来。",
                "生活的秩序，有时候就藏在一顿饭里。",
                "先把胃照顾好，其他事慢慢来。",
                "这一口，是今天很具体的满足感。"
            ]
        } else if lowercasedContext.contains("travel") || lowercasedContext.contains("street") || lowercasedContext.contains("walking") {
            captions = [
                "走到这里的时候，刚好想把这一刻留下。",
                "路上的风景不一定盛大，但很适合慢慢看。",
                "今天的坐标，交给这张照片来记。",
                "出门走走，才发现日常也会换一种光。",
                "把脚步放慢一点，城市会露出更多细节。"
            ]
        } else if lowercasedContext.contains("work") {
            captions = [
                "把事情一件件理顺，今天也算稳稳推进。",
                "桌面不一定完美，但状态正在慢慢上线。",
                "认真工作的时候，也要给自己留一点呼吸感。",
                "今天的进度，就从这个角落开始。",
                "把注意力收回来，事情就会一点点清楚。"
            ]
        } else {
            captions = [
                "这一刻没有太多解释，但值得被留下。",
                "普通的一天，也会有刚好想记录的瞬间。",
                "把眼前这一点生活感，先收进照片里。",
                "不必很特别，刚好真实就很好。",
                "今天的小片段，替我保存一下。"
            ]
        }

        return CloudEnhancementResponse(
            captions: captions,
            provider: config.provider.rawValue,
            model: "mock-v1",
            inputTokens: 0,
            outputTokens: 0,
            estimatedCost: 0,
            remainingQuota: nil
        )
    }
}

private struct CloudErrorEnvelope: Decodable {
    let error: CloudErrorPayload
}

private struct CloudErrorPayload: Decodable {
    let code: String
    let message: String
}
