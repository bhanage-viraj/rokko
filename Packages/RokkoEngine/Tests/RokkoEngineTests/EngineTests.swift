//
//  EngineTests.swift
//  BKT maths against hand-computed values, evidence rules, level bands, hint ladder (docs/ENGINE.md §9).
//

import Foundation
import Testing
import RokkoContent
@testable import RokkoEngine

private enum Fixtures {
    static let config: EngineConfig = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("rokko/Content/EngineConfig.json")
        return try! EngineConfig.load(from: url)
    }()
}

private func close(_ a: Double, _ b: Double, _ tol: Double = 1e-6) -> Bool { abs(a - b) < tol }

@Suite("BKT")
struct BKTTests {
    let bkt = BKTModel(Fixtures.config.bkt)

    @Test func correctFromStart() {
        // P 0.10, S 0.10, G 1/3: post = 0.09 / (0.09 + 0.9 × 1/3) = 0.230769; next = post + (1 − post) × 0.15
        #expect(close(bkt.update(0.1, with: .correct(guess: 1.0 / 3)), 0.346154))
    }

    @Test func incorrectFromStart() {
        // post = 0.01 / (0.01 + 0.9 × 2/3) = 0.016393; next = 0.163934
        #expect(close(bkt.update(0.1, with: .incorrect(guess: 1.0 / 3)), 0.163934))
    }

    @Test func wobblySlipIsGentlerOnWrongAnswers() {
        // S 0.30: post = 0.03 / (0.03 + 0.9 × 2/3) = 0.047619; next = 0.190476
        #expect(close(bkt.update(0.1, with: .incorrect(guess: 1.0 / 3), wobbly: true), 0.190476))
        #expect(bkt.update(0.1, with: .incorrect(guess: 1.0 / 3), wobbly: true) > bkt.update(0.1, with: .incorrect(guess: 1.0 / 3)))
    }

    @Test func ignoredChangesNothing() {
        #expect(bkt.update(0.42, with: .ignored(.afterArrow)) == 0.42)
    }

    @Test func clamped() {
        var p = 0.5
        for _ in 0..<200 { p = bkt.update(p, with: .correct(guess: 0.01)) }
        #expect(p == Fixtures.config.bkt.clampMax)
    }

    @Test func easierGuessMeansSmallerRise() {
        // Right out of 3 cards proves less than right out of 6.
        #expect(bkt.update(0.1, with: .correct(guess: 1.0 / 6)) > bkt.update(0.1, with: .correct(guess: 1.0 / 3)))
    }
}

@Suite("Evidence rules")
struct EvidenceTests {
    func result(_ correct: Bool, _ hint: HintStep, ms: Double? = 3000) -> TargetResult {
        TargetResult(skill: .king, correct: correct, hint: hint, guess: 0.25, responseMs: ms)
    }

    @Test func hintLadderEvidence() {
        let l = Learner(Fixtures.config)
        #expect(l.evidence(for: result(true, .none)) == .correct(guess: 0.25))
        #expect(l.evidence(for: result(true, .clue)) == .correct(guess: 0.5))
        #expect(l.evidence(for: result(true, .arrow)) == .ignored(.afterArrow))
        #expect(l.evidence(for: result(false, .reveal)) == .incorrect(guess: 0.25))
    }

    @Test func hint1GuessIsCapped() {
        let l = Learner(Fixtures.config)
        let r = TargetResult(skill: .king, correct: true, hint: .clue, guess: 0.5, responseMs: nil)
        #expect(l.evidence(for: r) == .correct(guess: 0.6))
    }

    @Test func fastTapNeedsWarmup() {
        var l = Learner(Fixtures.config)
        // Before 10 responses nothing is ignored, however fast.
        for _ in 0..<9 { l.record(result(true, .none, ms: 3000)) }
        #expect(l.evidence(for: result(true, .none, ms: 100)) == .correct(guess: 0.25))
        l.record(result(true, .none, ms: 3000))
        // Median 3000 → under 1200 ms is a fast tap.
        #expect(l.evidence(for: result(true, .none, ms: 1100)) == .ignored(.fastTap))
        #expect(l.evidence(for: result(true, .none, ms: 1300)) == .correct(guess: 0.25))
        // Hint 3 is never ignored.
        #expect(l.evidence(for: result(false, .reveal, ms: 100)) == .incorrect(guess: 0.25))
    }

    @Test func rollingMedian() {
        var t = ResponseTimes(Fixtures.config.fastTap)
        for ms in 1...30 { t.add(Double(ms) * 100) }
        // Last 20 = 1100…3000 → median 2050.
        #expect(t.median == 2050)
    }

    @Test func learnerUpdatesOnlyThatSkill() {
        var l = Learner(Fixtures.config)
        l.record(TargetResult(skill: .rook, correct: true, hint: .none, guess: 1.0 / 3, responseMs: 3000))
        #expect(close(l.known(.rook), 0.346154))
        #expect(l.known(.king) == Fixtures.config.bkt.pL0)
        #expect(l.log.count == 1)
    }
}

@Suite("Level selector")
struct LevelTests {
    // The level 4–6 rules stay tested with the cap lifted (the app caps at levels.maxLevel).
    let s = LevelSelector(Fixtures.config.levels, maxLevel: 6)

    func level(_ p: Double, last: Int?, colour: Double = 1, charcoal: Bool = true, wobbly: Bool = false) -> Int {
        s.level(p: p, lastLevel: last, colour: colour, charcoalIntroSeen: charcoal, wobbly: wobbly)
    }

    @Test func bands() {
        #expect(s.band(for: 0.1) == 1)
        #expect(s.band(for: 0.3) == 2)
        #expect(s.band(for: 0.59) == 3)
        #expect(s.band(for: 0.9) == 6)
        #expect(s.isMastered(0.95))
        #expect(!s.isMastered(0.94))
    }

    @Test func bufferOnTheWayUp() {
        #expect(level(0.32, last: 1) == 1)     // past 0.30, not past 0.35
        #expect(level(0.35, last: 1) == 2)
    }

    @Test func bufferOnTheWayDown() {
        #expect(level(0.27, last: 2) == 2)     // under 0.30, not under 0.25
        #expect(level(0.24, last: 2) == 1)
    }

    @Test func oneStepAtATime() {
        #expect(level(0.99, last: 1) == 2)
        #expect(level(0.01, last: 6) == 5)
    }

    @Test func gates() {
        #expect(level(0.8, last: 4, charcoal: false) == 4)
        #expect(level(0.8, last: 4, charcoal: true) == 5)
        #expect(level(0.94, last: 5, colour: 0.4) == 5)
        #expect(level(0.94, last: 5, colour: 0.6) == 6)
    }

    @Test func wobblyOneLower() {
        #expect(level(0.5, last: 3, wobbly: true) == 2)
        #expect(level(0.1, last: 1, wobbly: true) == 1)
    }
}

@Suite("Hint ladder")
struct HintLadderTests {
    @Test func climbsAndStops() {
        var h = HintLadder()
        #expect(h.step == .none)
        #expect(h.stepUp(.wrongAnswer) == .clue)
        #expect(h.stepUp(.idle) == .arrow)
        #expect(h.stepUp(.wrongAnswer) == .reveal)
        #expect(h.isRevealed)
        #expect(h.stepUp(.idle) == .reveal)
        #expect(h.triggers == [.wrongAnswer, .idle, .wrongAnswer])
        h.reset()
        #expect(h.step == .none && h.triggers.isEmpty)
    }

    @Test func freeTryGetsNoHint() {
        var h = HintLadder(freeTries: 1)
        #expect(h.stepUp(.wrongAnswer) == .none)
        #expect(h.wrongAnswers == 1)
        #expect(h.stepUp(.wrongAnswer) == .clue)
        #expect(h.stepUp(.wrongAnswer) == .arrow)
        #expect(h.stepUp(.wrongAnswer) == .reveal)
        #expect(h.triggers == [.wrongAnswer, .wrongAnswer, .wrongAnswer])
        h.reset()
        #expect(h.wrongAnswers == 0)
        #expect(h.stepUp(.wrongAnswer) == .none, "free try comes back for each target")
    }

    @Test func idleNeverReveals() {
        var h = HintLadder()
        #expect(h.stepUp(.idle) == .clue)
        #expect(h.stepUp(.idle) == .arrow)
        #expect(h.stepUp(.idle) == .arrow, "waiting alone never shows the answer")
        #expect(h.stepUp(.wrongAnswer) == .reveal)
    }

    @Test func configHints() {
        let c = Fixtures.config.hints
        #expect(c.idleHints == false)
        #expect(c.freeTries == 1)
        #expect(HintLadder.idleSeconds(c, calmOrWobbly: false) == nil)
        #expect(HintLadder.idleSeconds(c, calmOrWobbly: true) == nil)
    }
}


@Suite("Cheer picker")
struct CheerPickerTests {
    @Test func sameRoundSameCheers() {
        var a = CheerPicker(seed: "001-3-03-01-1-401"), b = CheerPicker(seed: "001-3-03-01-1-401")
        let x = (0..<10).map { _ in a.next(from: VoiceKeys.cheers) }
        let y = (0..<10).map { _ in b.next(from: VoiceKeys.cheers) }
        #expect(x == y)
    }

    @Test func neverTwiceInARow() {
        for seed in ["001-1-01-01-1-1", "001-3-04-03-6-9", "001-3-05-05-2-77"] {
            var p = CheerPicker(seed: seed)
            let said = (0..<40).map { _ in p.next(from: VoiceKeys.cheers) }
            #expect(zip(said, said.dropFirst()).allSatisfy { $0 != $1 }, "\(seed)")
        }
    }

    @Test func wordsChange() {
        var p = CheerPicker(seed: "001-3-03-01-1-401")
        let said = Set((0..<12).map { _ in p.next(from: VoiceKeys.cheers) })
        #expect(said.count >= 3, "cheers should vary within a round")
    }
}
