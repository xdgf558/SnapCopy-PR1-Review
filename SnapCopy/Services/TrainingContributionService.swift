import Foundation

final class TrainingContributionService {
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
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func submitConsent(_ request: TrainingContributionConsentRequest) async throws -> TrainingContributionResponse {
        guard config.enabled else {
            return localAcceptance(consentId: request.consentId, sampleId: nil, message: "Contribution consent kept locally.")
        }

        guard let endpoint = config.endpoint else {
            return localAcceptance(consentId: request.consentId, sampleId: nil, message: "Contribution consent kept locally.")
        }

        return try await post(request, endpoint: endpoint, path: "api/contributions/consent")
    }

    func submitSample(_ request: TrainingContributionSampleRequest) async throws -> TrainingContributionResponse {
        guard request.consentGranted else {
            throw TrainingContributionError.consentRequired
        }

        guard !request.imageUploadEnabled else {
            throw TrainingContributionError.imageUploadDisabled
        }

        guard config.enabled else {
            return localAcceptance(
                consentId: request.consentId,
                sampleId: request.sampleId,
                message: "Contribution sample kept locally."
            )
        }

        guard let endpoint = config.endpoint else {
            return localAcceptance(
                consentId: request.consentId,
                sampleId: request.sampleId,
                message: "Contribution sample kept locally."
            )
        }

        return try await post(request, endpoint: endpoint, path: "api/contributions/sample")
    }

    private func post<RequestBody: Encodable>(
        _ body: RequestBody,
        endpoint: URL,
        path: String
    ) async throws -> TrainingContributionResponse {
        let url = endpoint.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("SnapCopy-iOS-Debug", forHTTPHeaderField: "X-SnapCopy-App")
        urlRequest.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TrainingContributionError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = cloudErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                throw TrainingContributionError.requestFailed(message)
            }

            return try decoder.decode(TrainingContributionResponse.self, from: data)
        } catch let error as TrainingContributionError {
            throw error
        } catch {
            throw TrainingContributionError.requestFailed(error.localizedDescription)
        }
    }

    private func localAcceptance(
        consentId: UUID,
        sampleId: UUID?,
        message: String
    ) -> TrainingContributionResponse {
        TrainingContributionResponse(
            accepted: true,
            consentId: consentId,
            sampleId: sampleId,
            storageMode: "local-only",
            retentionPolicy: "Original photos are not uploaded.",
            message: message
        )
    }

    private func cloudErrorMessage(from data: Data) -> String? {
        guard let envelope = try? decoder.decode(TrainingContributionErrorEnvelope.self, from: data) else {
            return nil
        }

        return "\(envelope.error.code): \(envelope.error.message)"
    }
}

enum TrainingContributionError: Error, Equatable {
    case consentRequired
    case imageUploadDisabled
    case invalidResponse
    case requestFailed(String)
}

extension TrainingContributionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .consentRequired:
            "Training contribution requires user consent."
        case .imageUploadDisabled:
            "Image upload is disabled in this build."
        case .invalidResponse:
            "Training contribution returned an invalid response."
        case .requestFailed(let message):
            "Training contribution failed: \(message)"
        }
    }
}

private struct TrainingContributionErrorEnvelope: Decodable {
    let error: TrainingContributionErrorPayload
}

private struct TrainingContributionErrorPayload: Decodable {
    let code: String
    let message: String
}
