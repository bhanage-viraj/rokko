//
//  HintLadder.swift
//  docs/ENGINE.md §5. none → 1 clue card → 2 arrow → 3 reveal (the answer shows itself).
//  Steps up on a wrong answer (after `freeTries` free ones) or, if idle hints are on, after the idle
//  time. Idle never goes past the arrow: only the child's answers can reach the reveal.
//  Resets each round (drag games: each target).
//

import RokkoContent

public enum HintStep: Int, Comparable, Sendable, CaseIterable {
    case none = 0
    /// Half-transparent clue card (animal half + piece half). "Look at this. The elephant has a tower. The Rook is a tower too."
    case clue = 1
    /// Honey arrow bobbing toward the right answer / right slot. "Look here."
    case arrow = 2
    /// The answer lights up and names itself. Counts as not known.
    case reveal = 3

    public static func < (a: HintStep, b: HintStep) -> Bool { a.rawValue < b.rawValue }
}

public struct HintLadder: Sendable {
    public enum Trigger: Sendable { case wrongAnswer, idle }

    public private(set) var step: HintStep = .none
    /// What moved the ladder up, in order (for logs and tests).
    public private(set) var triggers: [Trigger] = []
    /// Wrong answers for this target so far.
    public private(set) var wrongAnswers = 0
    private let freeTries: Int

    /// - freeTries: wrong answers that get no hint (EngineConfig › hints › freeTries).
    public init(freeTries: Int = 0) {
        self.freeTries = max(0, freeTries)
    }

    /// One step up, or no change: a free wrong answer, idle at the arrow already, or past `.reveal`.
    /// Returns the step after the call.
    @discardableResult
    public mutating func stepUp(_ trigger: Trigger) -> HintStep {
        guard step != .reveal else { return step }
        switch trigger {
        case .wrongAnswer:
            wrongAnswers += 1
            guard wrongAnswers > freeTries else { return step }
        case .idle:
            guard step < .arrow else { return step }
        }
        step = HintStep(rawValue: step.rawValue + 1) ?? .reveal
        triggers.append(trigger)
        return step
    }

    public mutating func reset() {
        step = .none
        triggers = []
        wrongAnswers = 0
    }

    public var isRevealed: Bool { step == .reveal }

    /// Seconds without input before the next step: 12, or 18 in Calm or Wobbly. Nil when idle hints are off.
    public static func idleSeconds(_ hints: EngineConfig.Hints, calmOrWobbly: Bool) -> Double? {
        guard hints.idleHints else { return nil }
        return calmOrWobbly ? hints.idleSecondsCalmOrWobbly : hints.idleSeconds
    }
}
