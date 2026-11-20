//
//  BKTModel.swift
//  Bayesian Knowledge Tracing, docs/ENGINE.md §2. One probability per skill: P(known).
//
//    correct:   post = P·(1−S) / (P·(1−S) + (1−P)·G)
//    incorrect: post = P·S / (P·S + (1−P)·(1−G))
//    next P     = post + (1 − post)·T          clamped to [0.001, 0.999]
//
//  S = slip (knows it but answers wrong), G = guess (doesn't know it but answers right),
//  T = transit (learns it from this practice).
//

import RokkoContent

/// What one answer tells BKT.
public enum Evidence: Equatable, Sendable {
    case correct(guess: Double)
    case incorrect(guess: Double)
    /// No update: right only after the arrow (hint 2), or a tap too fast to be a real answer.
    case ignored(IgnoreReason)

    public enum IgnoreReason: Equatable, Sendable { case afterArrow, fastTap }
}

public struct BKTModel: Sendable {
    public let params: EngineConfig.BKT

    public init(_ params: EngineConfig.BKT) { self.params = params }

    /// The new P(known) after one piece of evidence. Wobbly mood uses the higher slip (0.30).
    public func update(_ p: Double, with evidence: Evidence, wobbly: Bool = false) -> Double {
        let s = wobbly ? params.slipWobbly : params.slip
        let post: Double
        switch evidence {
        case .ignored:
            return p
        case .correct(let g):
            post = p * (1 - s) / (p * (1 - s) + (1 - p) * g)
        case .incorrect(let g):
            post = p * s / (p * s + (1 - p) * (1 - g))
        }
        let next = post + (1 - post) * params.transit
        return min(params.clampMax, max(params.clampMin, next))
    }
}
