//
//  Learner.swift
//  Turns what happened on one target into BKT evidence (docs/ENGINE.md §2 "Evidence per round")
//  and keeps every skill's P(known).
//
//    Correct, no hint            → correct
//    Correct after hint 1        → correct, guess = min(0.6, guess × 2)
//    Correct after hint 2        → no update
//    Hint 3 reached              → incorrect
//    Faster than 0.4 × median    → no update (median needs 10 responses first)
//

import RokkoContent

/// One finished target: a choice round, one link, one figure placed, or one finished shelf.
public struct TargetResult: Equatable, Sendable {
    public let skill: Skill
    /// Answered right by the child. False only when hint 3 showed the answer (or a black-twin pick).
    public let correct: Bool
    /// The highest hint shown before the answer.
    public let hint: HintStep
    /// Chance of getting it right by guessing (1 ÷ cards, 1 ÷ pieces left, …).
    public let guess: Double
    /// Time from the target becoming active to the answer. Nil = not timed (e.g. a finished shelf).
    public let responseMs: Double?

    public init(skill: Skill, correct: Bool, hint: HintStep, guess: Double, responseMs: Double?) {
        self.skill = skill
        self.correct = correct
        self.hint = hint
        self.guess = guess
        self.responseMs = responseMs
    }
}

/// The child's usual response time: median of the first 10, then a rolling median of the last 20.
public struct ResponseTimes: Sendable, Equatable {
    public let warmup: Int
    public let window: Int
    public private(set) var times: [Double] = []

    public init(_ c: EngineConfig.FastTap, times: [Double] = []) {
        warmup = c.warmupResponses
        window = c.rollingWindow
        self.times = Array(times.suffix(c.rollingWindow))
    }

    /// Nil until `warmup` responses exist.
    public var median: Double? {
        guard times.count >= warmup else { return nil }
        let recent = times.suffix(window).sorted()
        let n = recent.count
        return n % 2 == 1 ? recent[n / 2] : (recent[n / 2 - 1] + recent[n / 2]) / 2
    }

    public mutating func add(_ ms: Double) {
        times.append(ms)
        if times.count > window { times.removeFirst(times.count - window) }
    }
}

public struct Learner: Sendable {
    public let bkt: BKTModel
    public let fastTap: EngineConfig.FastTap
    public private(set) var p: [Skill: Double]
    public private(set) var responseTimes: ResponseTimes
    /// Every result and what it did, newest last (DEV panel, tests).
    public private(set) var log: [(result: TargetResult, evidence: Evidence, before: Double, after: Double)] = []

    /// - start: saved P(known) per skill (missing skills start at pL0).
    /// - responseTimes: saved response times (ms), oldest first, so the median survives a restart.
    public init(_ config: EngineConfig, start: [Skill: Double] = [:], responseTimes times: [Double] = []) {
        bkt = BKTModel(config.bkt)
        fastTap = config.fastTap
        p = Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, start[$0] ?? config.bkt.pL0) })
        responseTimes = ResponseTimes(config.fastTap, times: times)
    }

    public func known(_ skill: Skill) -> Double { p[skill] ?? bkt.params.pL0 }

    /// The evidence rule on its own (no state change).
    public func evidence(for r: TargetResult) -> Evidence {
        if r.hint == .reveal || !r.correct { return .incorrect(guess: r.guess) }
        if let ms = r.responseMs, let median = responseTimes.median, ms < fastTap.ratio * median {
            return .ignored(.fastTap)
        }
        switch r.hint {
        case .none: return .correct(guess: r.guess)
        case .clue: return .correct(guess: min(bkt.params.hint1GuessMax, r.guess * bkt.params.hint1GuessMultiplier))
        case .arrow: return .ignored(.afterArrow)
        case .reveal: return .incorrect(guess: r.guess)
        }
    }

    /// Applies one result. Returns the evidence used.
    @discardableResult
    public mutating func record(_ r: TargetResult, wobbly: Bool = false) -> Evidence {
        let e = evidence(for: r)
        let before = known(r.skill)
        let after = bkt.update(before, with: e, wobbly: wobbly)
        p[r.skill] = after
        // Fast taps are left out of the median so it doesn't drift down.
        if let ms = r.responseMs, e != .ignored(.fastTap) { responseTimes.add(ms) }
        log.append((r, e, before, after))
        return e
    }
}
