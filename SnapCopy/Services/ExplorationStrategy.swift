import Foundation

struct ExplorationStrategy {
    func selectDisplayBatch(
        from scoredCaptions: [ScoredCaptionRecommendation],
        count: Int = 5
    ) -> [ScoredCaptionRecommendation] {
        guard count > 0 else {
            return []
        }

        let sortedCaptions = scoredCaptions.sorted {
            if $0.score == $1.score {
                return $0.candidate.text < $1.candidate.text
            }

            return $0.score > $1.score
        }

        guard sortedCaptions.count > count else {
            return sortedCaptions.enumerated().map { index, item in
                item.withExploration(index == sortedCaptions.count - 1 && sortedCaptions.count > 1)
            }
        }

        let topCount = max(0, count - 1)
        let topCaptions = Array(sortedCaptions.prefix(topCount))
        let topStyles = Set(topCaptions.map(\.features.style))
        let explorationPool = sortedCaptions.dropFirst(topCount)
        let explorationCaption = explorationPool.first { candidate in
            !topStyles.contains(candidate.features.style)
        } ?? explorationPool.first

        var displayBatch = topCaptions.map { $0.withExploration(false) }

        if let explorationCaption {
            displayBatch.append(explorationCaption.withExploration(true))
        }

        if displayBatch.count < count {
            let existingIDs = Set(displayBatch.map(\.id))
            let remaining = sortedCaptions
                .filter { !existingIDs.contains($0.id) }
                .prefix(count - displayBatch.count)
                .map { $0.withExploration(false) }
            displayBatch.append(contentsOf: remaining)
        }

        return displayBatch
    }
}

private extension ScoredCaptionRecommendation {
    func withExploration(_ isExploration: Bool) -> ScoredCaptionRecommendation {
        ScoredCaptionRecommendation(
            candidate: candidate,
            features: features,
            score: score,
            scoreComponents: scoreComponents,
            isExploration: isExploration
        )
    }
}
