import Foundation

nonisolated enum PrecipitationExpectationCategory: Equatable, Sendable {
    case trace
    case light
    case wet
    case strong
}

nonisolated struct PrecipitationExpectation: Hashable, Sendable {
    let expectedAmount: Double
    let sourceAmount: Double
    let probability: Double
    let peakHour: HourlyForecastEntry?
    let peakExpectedAmount: Double

    init(
        expectedAmount: Double,
        sourceAmount: Double,
        probability: Double,
        peakHour: HourlyForecastEntry? = nil,
        peakExpectedAmount: Double? = nil
    ) {
        let clampedSourceAmount = max(0, sourceAmount)
        let clampedProbability = Self.clampedProbability(probability)
        self.expectedAmount = max(0, expectedAmount)
        self.sourceAmount = clampedSourceAmount
        self.probability = clampedProbability
        self.peakHour = peakHour
        self.peakExpectedAmount = peakExpectedAmount ?? Self.weightedAmount(
            precipitation: clampedSourceAmount,
            probability: clampedProbability
        )
    }

    init(sourceAmount: Double, probability: Double) {
        let clampedSourceAmount = max(0, sourceAmount)
        let clampedProbability = Self.clampedProbability(probability)
        self.init(
            expectedAmount: Self.weightedAmount(
                precipitation: clampedSourceAmount,
                probability: clampedProbability
            ),
            sourceAmount: clampedSourceAmount,
            probability: clampedProbability
        )
    }

    static func day(
        from hours: [HourlyForecastEntry],
        fallbackAmount: Double = 0,
        fallbackProbability: Double = 0
    ) -> PrecipitationExpectation {
        guard !hours.isEmpty else {
            return PrecipitationExpectation(
                sourceAmount: fallbackAmount,
                probability: fallbackProbability
            )
        }

        let sourceAmount = hours.reduce(0) { partial, hour in
            partial + max(0, hour.precipitation)
        }
        let probability = hours.map { clampedProbability($0.precipitationProbability) }.max() ?? 0
        let expectedAmount = hours.reduce(0) { partial, hour in
            partial + weightedAmount(
                precipitation: hour.precipitation,
                probability: hour.precipitationProbability
            )
        }
        let peakHour = hours.max { lhs, rhs in
            let lhsExpected = weightedAmount(
                precipitation: lhs.precipitation,
                probability: lhs.precipitationProbability
            )
            let rhsExpected = weightedAmount(
                precipitation: rhs.precipitation,
                probability: rhs.precipitationProbability
            )

            if abs(lhsExpected - rhsExpected) < 0.0001 {
                return lhs.precipitationProbability < rhs.precipitationProbability
            }

            return lhsExpected < rhsExpected
        }
        let peakExpectedAmount = peakHour.map {
            weightedAmount(
                precipitation: $0.precipitation,
                probability: $0.precipitationProbability
            )
        } ?? 0

        return PrecipitationExpectation(
            expectedAmount: expectedAmount,
            sourceAmount: sourceAmount,
            probability: probability,
            peakHour: peakHour,
            peakExpectedAmount: peakExpectedAmount
        )
    }

    static func weightedAmount(precipitation: Double, probability: Double) -> Double {
        max(0, precipitation) * clampedProbability(probability) / 100
    }

    var category: PrecipitationExpectationCategory {
        switch expectedAmount {
        case ..<0.5:
            return .trace
        case ..<2:
            return .light
        case ..<5:
            return .wet
        default:
            return .strong
        }
    }

    var hasHighChanceLowAmountShape: Bool {
        probability >= 60 && sourceAmount < 2 && expectedAmount < 2
    }

    var hasLowChanceHighAmountShape: Bool {
        probability < 55 && sourceAmount >= 3
    }

    private static func clampedProbability(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
