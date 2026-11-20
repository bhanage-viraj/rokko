//
//  RoundPlannerTests.swift
//  Planner rules (docs/ENGINE.md §4, §9): never the same piece twice, Types 1/2 alternate, review every
//  4th round, Module 3 cycle, gates and block end, level skill, pool round pick, check-in signal.
//

import Foundation
import Testing
import RokkoContent
@testable import RokkoEngine

private enum PlannerFixtures {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("rokko/Content")
    static let config = try! EngineConfig.load(from: root.appendingPathComponent("EngineConfig.json"))
    static let pool = try! ExercisePool.load(from: root.appendingPathComponent("Lesson1/exercise_pool.json"))
    static let planner = RoundPlanner(config: config, pool: pool)
}

@Suite("Round planner")
struct RoundPlannerTests {
    let planner = PlannerFixtures.planner
    let config = PlannerFixtures.config

    @Test func modulePiecesComeFromThePool() {
        #expect(planner.pieces(module: 1) == [.king, .rook, .knight])
        #expect(planner.pieces(module: 2) == [.queen, .bishop, .pawn])
        #expect(planner.pieces(module: 3).isEmpty)
        #expect(planner.choiceCode(piece: .rook, type: 1) == "001-1-01-02")
        #expect(planner.choiceCode(piece: .pawn, type: 2) == "001-2-02-06")
    }

    @Test func targetsTheLowestPieceAndNeverTheSameTwice() {
        let p: [Skill: Double] = [.king: 0.5, .rook: 0.2, .knight: 0.3]
        var state = PlannerState()
        let first = planner.next(module: 1, state: state) { p[$0] ?? 0.1 }
        #expect(first.piece == .rook)
        #expect(first.exerciseCode == "001-1-01-02")
        planner.played(first, state: &state)
        let second = planner.next(module: 1, state: state) { p[$0] ?? 0.1 }
        #expect(second.piece == .knight)
    }

    @Test func typesOneAndTwoAlternateForAPiece() {
        var state = PlannerState()
        state.lastType[.king] = 1
        state.lastPiece = .rook
        let p: [Skill: Double] = [.king: 0.1, .rook: 0.5, .knight: 0.5]
        let r = planner.next(module: 1, state: state) { p[$0] ?? 0.1 }
        #expect(r.piece == .king)
        #expect(r.type == 2)
        #expect(r.exerciseCode == "001-1-02-04")
    }

    @Test func everyFourthRoundInModule2ReviewsModule1() {
        var state = PlannerState()
        state.roundsInBlock = config.planner.reviewEvery - 1
        let p: [Skill: Double] = [.king: 0.7, .rook: 0.65, .knight: 0.9, .queen: 0.1, .bishop: 0.1, .pawn: 0.1]
        let r = planner.next(module: 2, state: state) { p[$0] ?? 0.1 }
        #expect(r.isReview)
        #expect(r.piece == .rook)
        state.roundsInBlock = 0
        let normal = planner.next(module: 2, state: state) { p[$0] ?? 0.1 }
        #expect(!normal.isReview)
        #expect(planner.pieces(module: 2).contains(normal.piece!))
    }

    @Test func masteredPiecesAreLeftForReview() {
        let p: [Skill: Double] = [.king: 0.97, .rook: 0.4, .knight: 0.96]
        var state = PlannerState()
        state.lastPiece = .rook
        // Rook is the only open piece; it was just played, so a mastered piece fills in rather than repeating.
        let r = planner.next(module: 1, state: state) { p[$0] ?? 0.1 }
        #expect(r.piece != .rook)
        state.lastPiece = .king
        #expect(planner.next(module: 1, state: state) { p[$0] ?? 0.1 }.piece == .rook)
    }

    @Test func module3CyclesThroughTheDragGames() {
        var state = PlannerState()
        let high: (Skill) -> Double = { _ in 0.97 }
        var codes: [String] = []
        for _ in 0..<config.planner.module3Cycle.count {
            let r = planner.next(module: 3, state: state, known: high)
            codes.append(r.exerciseCode)
            planner.played(r, state: &state)
            state.roundsInBlock = 0   // keep review turns out of this test
        }
        #expect(codes == config.planner.module3Cycle.map { "001-3-\($0)" })
    }

    @Test func module3ReviewsAPieceUnderMastery() {
        var state = PlannerState()
        state.roundsInBlock = config.planner.reviewEvery - 1
        let p: [Skill: Double] = [.king: 0.97, .queen: 0.97, .rook: 0.97, .bishop: 0.8, .knight: 0.97, .pawn: 0.97]
        let r = planner.next(module: 3, state: state) { p[$0] ?? 0.97 }
        #expect(r.isReview)
        #expect(r.piece == .bishop)
    }

    @Test func blockEndsAtTheGateAfterTheMinimumRounds() {
        let gate = config.gates["module2"]
        let block = try! #require(planner.block(module: 1))
        var state = PlannerState()
        let met: (Skill) -> Double = { _ in 0.61 }
        let notMet: (Skill) -> Double = { $0 == .knight ? 0.59 : 0.9 }
        state.roundsInBlock = block.minRounds - 1
        #expect(!planner.blockEnds(module: 1, gate: gate, state: state, known: met))
        state.roundsInBlock = block.minRounds
        #expect(planner.blockEnds(module: 1, gate: gate, state: state, known: met))
        #expect(!planner.blockEnds(module: 1, gate: gate, state: state, known: notMet))
        // Always ends at the maximum, gate met or not.
        state.roundsInBlock = block.maxRounds
        #expect(planner.blockEnds(module: 1, gate: gate, state: state, known: notMet))
    }

    @Test func everyModuleIsThreeToSixRounds() {
        for module in 1...3 {
            let block = planner.block(module: module)
            #expect(block?.minRounds == 3)
            #expect(block?.maxRounds == 6)
        }
    }

    @Test func gatesUseTheConfiguredThresholds() {
        #expect(RoundPlanner.isMet(config.gates["module3"]!) { _ in 0.75 })
        #expect(!RoundPlanner.isMet(config.gates["module3"]!) { $0 == .pawn ? 0.74 : 0.9 })
        #expect(!RoundPlanner.isMet(config.gates["lessonComplete"]!) { $0 == .pawn ? 0.5 : 0.99 })
    }

    @Test func sittingIsFullAtTheMaximum() {
        var state = PlannerState()
        state.roundsThisSitting = 13
        #expect(!planner.sittingFull(module: 1, state: state))
        state.roundsThisSitting = 14
        #expect(planner.sittingFull(module: 1, state: state))
        state.newSitting()
        #expect(!planner.sittingFull(module: 1, state: state))
        #expect(state.roundsInBlock == 0)
    }

    @Test func levelSkillPerType() {
        let p: [Skill: Double] = [.king: 0.9, .queen: 0.3, .colour: 0.2, .teamMakeup: 0.4]
        let known: (Skill) -> Double = { p[$0] ?? 0.0 }
        #expect(planner.levelSkillP(type: 1, piece: .king, known: known) == 0.9)
        #expect(abs(planner.levelSkillP(type: 3, piece: nil, known: known) - 0.2) < 1e-9)
        #expect(planner.levelSkillP(type: 4, piece: nil, known: known) == 0.4)
        #expect(planner.levelSkillP(type: 5, piece: nil, known: known) == 0.2)
    }

    @Test func poolRoundIsPlaysModRounds() throws {
        let ex = try #require(PlannerFixtures.pool.exercise("001-1-01-01"))
        let rounds = ex.rounds(level: 1)
        #expect(RoundPlanner.round(in: ex, level: 1, plays: 0) == rounds[0])
        #expect(RoundPlanner.round(in: ex, level: 1, plays: rounds.count + 1) == rounds[1])
    }

    @Test func checkInSignalNeedsWrongsAndSlowdown() {
        let signal = SignalMonitor(config.signal)
        #expect(signal.suggestsCheckIn(roundsWithWrong: [true, false, true, true], lastResponseMs: 4000, medianMs: 2000))
        #expect(!signal.suggestsCheckIn(roundsWithWrong: [true, false, true, true], lastResponseMs: 2500, medianMs: 2000))
        #expect(!signal.suggestsCheckIn(roundsWithWrong: [true, false, false, true], lastResponseMs: 4000, medianMs: 2000))
        #expect(!signal.suggestsCheckIn(roundsWithWrong: [true, true, true], lastResponseMs: 4000, medianMs: nil))
    }

    @Test func noExerciseGoesAboveTheMaxLevel() {
        let selector = LevelSelector(config.levels)
        // Level 1 only for now (EngineConfig › levels.maxLevel).
        #expect(config.levels.maxLevel == 1)
        #expect(selector.level(p: 0.99, lastLevel: nil, colour: 0.99, charcoalIntroSeen: true, wobbly: false) == 1)
        #expect(selector.level(p: 0.99, lastLevel: 1, colour: 0.99, charcoalIntroSeen: true, wobbly: false) == 1)
        #expect(selector.level(p: 0.99, lastLevel: 6, colour: 0.99, charcoalIntroSeen: true, wobbly: false) == 1)
    }

    @Test func learnerRestoresResponseTimes() {
        let times = (1...12).map { Double($0) * 100 }
        let learner = Learner(config, responseTimes: times)
        #expect(learner.responseTimes.median == 650)
    }
}
