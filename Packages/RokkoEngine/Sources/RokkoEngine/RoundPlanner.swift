//
//  RoundPlanner.swift
//  Which exercise comes next inside a game block (docs/ENGINE.md §4), which level it plays at (§3),
//  and which pool round that is (§7). Pure and deterministic: same state → same plan.
//
//  Modules 1 · 2 (Types 1 and 2):
//    target = the module piece with the lowest P(known) that is not mastered; never the same piece twice
//    in a row; Types 1 and 2 alternate for the same piece; every `reviewEvery`-th round is a review of a
//    mastered or earlier-module piece (when there is one).
//  Module 3: cycles `module3Cycle` (Type 3 white, black → Type 4 → Type 5); every `reviewEvery`-th round
//    is a Type 1/2 review of a piece still under mastery.
//  The block ends when its gate is met and it has had `minRounds`, and always after `maxRounds`; after `maxRoundsPerSitting` the
//  Guardian is asked "Stop here for today" or "Keep going".
//

import RokkoContent

/// What the planner remembers inside a block. Saved with the lesson progress.
public struct PlannerState: Codable, Sendable, Equatable {
    public var roundsInBlock = 0
    public var roundsThisSitting = 0
    /// Target piece of the last Type 1/2 round.
    public var lastPiece: Piece?
    /// Type (1 or 2) last played for each piece, so the two alternate.
    public var lastType: [Piece: Int] = [:]
    /// Next position in `module3Cycle`.
    public var module3Next = 0

    public init() {}

    /// A new sitting: the block carries on, the per-sitting count starts again.
    public mutating func newSitting() { roundsThisSitting = 0 }
}

public struct PlannedRound: Equatable, Sendable {
    /// `LLL-M-TT-EE`
    public let exerciseCode: String
    public let type: Int
    /// Types 1 · 2: the piece asked about.
    public let piece: Piece?
    public let isReview: Bool
}

public struct RoundPlanner: Sendable {
    /// One Type 1/2 exercise: which piece it asks about, in which module.
    public struct ChoiceExercise: Equatable, Sendable {
        public let code: String
        public let module: Int
        public let type: Int
        public let piece: Piece
    }

    public let config: EngineConfig.Planner
    public let mastered: Double
    public let choiceExercises: [ChoiceExercise]
    /// Module 3 exercises by "TT-EE".
    public let module3: [String: (code: String, type: Int)]

    public init(config: EngineConfig, pool: ExercisePool) {
        self.config = config.planner
        mastered = config.levels.mastered
        var choices: [ChoiceExercise] = []
        var m3: [String: (String, Int)] = [:]
        for ex in pool.exercises {
            guard let code = ex.exerciseCode else { continue }
            if ex.type == 1 || ex.type == 2 {
                let first = ex.levelNumbers.first.flatMap { ex.rounds(level: $0).first }
                if case .choice(let c)? = first?.content {
                    choices.append(.init(code: ex.code, module: code.module, type: ex.type, piece: c.answer.piece))
                }
            } else {
                m3[String(format: "%02d-%02d", code.type, code.exercise)] = (ex.code, ex.type)
            }
        }
        choiceExercises = choices
        module3 = m3
    }

    /// The pieces taught in a module (Types 1/2 exercises of that module), in exercise order.
    public func pieces(module: Int) -> [Piece] {
        var out: [Piece] = []
        for ex in choiceExercises where ex.module == module && !out.contains(ex.piece) { out.append(ex.piece) }
        return out
    }

    public func choiceCode(piece: Piece, type: Int) -> String? {
        choiceExercises.first { $0.piece == piece && $0.type == type }?.code
    }

    // MARK: Next round

    public func next(module: Int, state: PlannerState, known: (Skill) -> Double) -> PlannedRound {
        let isReviewTurn = config.reviewEvery > 0 && (state.roundsInBlock + 1) % config.reviewEvery == 0

        if let m3 = module3Round(module: module, state: state, isReviewTurn: isReviewTurn, known: known) {
            return m3
        }

        let own = pieces(module: module)
        if isReviewTurn {
            let earlier = (1..<max(1, module)).flatMap { pieces(module: $0) }
            let review = earlier + own.filter { known(Skill($0)) >= mastered }
            if let piece = lowest(review, avoiding: state.lastPiece, known: known) {
                return choice(piece, state: state, review: true)
            }
        }
        let open = own.filter { known(Skill($0)) < mastered }
        let piece = lowest(open.isEmpty ? own : open, avoiding: state.lastPiece, known: known)
            ?? lowest(own, avoiding: state.lastPiece, known: known)
            ?? own.first ?? .king
        return choice(piece, state: state, review: false)
    }

    /// Module 3 (any module whose exercises are not Types 1/2): the cycle, with Type 1/2 reviews.
    private func module3Round(module: Int, state: PlannerState, isReviewTurn: Bool,
                              known: (Skill) -> Double) -> PlannedRound? {
        guard pieces(module: module).isEmpty, !config.module3Cycle.isEmpty else { return nil }
        if isReviewTurn {
            let weak = Piece.allCases.filter { choiceCode(piece: $0, type: 1) != nil && known(Skill($0)) < mastered }
            if let piece = lowest(weak, avoiding: state.lastPiece, known: known) {
                return choice(piece, state: state, review: true)
            }
        }
        for i in 0..<config.module3Cycle.count {
            let key = config.module3Cycle[(state.module3Next + i) % config.module3Cycle.count]
            if let ex = module3[key] { return PlannedRound(exerciseCode: ex.code, type: ex.type, piece: nil, isReview: false) }
        }
        return nil
    }

    private func choice(_ piece: Piece, state: PlannerState, review: Bool) -> PlannedRound {
        let type = config.alternateTypes12 ? (state.lastType[piece] == 1 ? 2 : 1) : 1
        let code = choiceCode(piece: piece, type: type) ?? choiceCode(piece: piece, type: 1) ?? ""
        return PlannedRound(exerciseCode: code, type: type, piece: piece, isReview: review)
    }

    /// Lowest P(known); ties go to the earlier piece. Skips `avoiding` unless it is the only one.
    private func lowest(_ pieces: [Piece], avoiding: Piece?, known: (Skill) -> Double) -> Piece? {
        let pool = config.neverSamePieceTwiceInARow ? pieces.filter { $0 != avoiding } : pieces
        return pool.enumerated().min { a, b in
            let pa = known(Skill(a.element)), pb = known(Skill(b.element))
            return pa != pb ? pa < pb : a.offset < b.offset
        }?.element
    }

    /// After a round is played.
    public func played(_ round: PlannedRound, state: inout PlannerState) {
        state.roundsInBlock += 1
        state.roundsThisSitting += 1
        if let piece = round.piece {
            state.lastPiece = piece
            state.lastType[piece] = round.type
        } else {
            state.module3Next = (state.module3Next + 1) % max(1, config.module3Cycle.count)
        }
    }

    // MARK: Block end

    public func block(module: Int) -> EngineConfig.Planner.Block? { config.blocks["module\(module)"] }

    /// Gate met and the block has had its minimum rounds, or the block has had its maximum rounds.
    public func blockEnds(module: Int, gate: EngineConfig.Gate?, state: PlannerState, known: (Skill) -> Double) -> Bool {
        if let max = block(module: module)?.maxRounds, state.roundsInBlock >= max { return true }
        guard let gate else { return false }
        return Self.isMet(gate, known: known) && state.roundsInBlock >= (block(module: module)?.minRounds ?? 0)
    }

    /// This sitting has had the block's maximum rounds: time to ask the Guardian.
    public func sittingFull(module: Int, state: PlannerState) -> Bool {
        guard let max = block(module: module)?.maxRoundsPerSitting else { return false }
        return state.roundsThisSitting >= max
    }

    public static func isMet(_ gate: EngineConfig.Gate, known: (Skill) -> Double) -> Bool {
        gate.skills.allSatisfy { known($0) >= gate.min }
    }

    // MARK: Level and round

    /// The P(known) that sets an exercise's level (ENGINE §3): Types 1/2 the piece; Type 3 the mean of
    /// the piece skills; Type 4 Team make-up; Type 5 Colour.
    public func levelSkillP(type: Int, piece: Piece?, known: (Skill) -> Double) -> Double {
        switch type {
        case 1, 2:
            return known(Skill(piece ?? .king))
        case 3:
            let all = Piece.allCases.map { known(Skill($0)) }
            return all.reduce(0, +) / Double(all.count)
        case 4:
            return known(.teamMakeup)
        default:
            return known(.colour)
        }
    }

    /// The pool round at a level: rounds in pool order, index = plays at that level mod rounds there.
    public static func round(in exercise: PoolExercise, level: Int, plays: Int) -> PoolRound? {
        let rounds = exercise.rounds(level: level)
        guard !rounds.isEmpty else { return nil }
        return rounds[((plays % rounds.count) + rounds.count) % rounds.count]
    }
}

/// When the engine suggests a check-in (ENGINE §6): `wrongCount` of the last `wrongInLast` rounds had a
/// try that did not fit, and the last response time is above `slowdownRatio` × the child's median.
/// It only makes the Guardian button glow; mood is set by the Guardian.
public struct SignalMonitor: Sendable {
    public let config: EngineConfig.Signal

    public init(_ config: EngineConfig.Signal) { self.config = config }

    /// - roundsWithWrong: one entry per finished round, newest last (true = at least one try did not fit).
    public func suggestsCheckIn(roundsWithWrong: [Bool], lastResponseMs: Double?, medianMs: Double?) -> Bool {
        let recent = roundsWithWrong.suffix(config.wrongInLast)
        guard recent.filter({ $0 }).count >= config.wrongCount else { return false }
        guard let last = lastResponseMs, let median = medianMs, median > 0 else { return false }
        return last > config.slowdownRatio * median
    }
}
