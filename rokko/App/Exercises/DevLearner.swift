//
//  DevLearner.swift
//  BKT for the developer exercise screens: one Learner shared by every round played while the
//  Developer screen is open. Starts fresh (every skill at pL0) each time; nothing is saved.
//  The real lesson keeps its Learner in SwiftData through the LessonCoordinator (not built yet).
//

import Foundation
import Observation
import RokkoContent
import RokkoEngine

@MainActor
@Observable
final class DevLearner {
    private(set) var learner: Learner
    private let config: EngineConfig

    init(config: EngineConfig) {
        self.config = config
        learner = Learner(config)
    }

    func record(_ result: TargetResult) {
        learner.record(result)
    }

    func reset() {
        learner = Learner(config)
    }

    /// The skill BKT uses to pick this exercise's level (docs/ENGINE.md §3).
    func levelSkillP(for exercise: PoolExercise) -> Double {
        switch exercise.type {
        case 1, 2:
            guard let round = exercise.levelNumbers.first.flatMap({ exercise.rounds(level: $0).first }),
                  case .choice(let c) = round.content else { return config.bkt.pL0 }
            return learner.known(Skill(c.answer.piece))
        case 3:
            // Mean of the six piece skills (the pieces involved in a link round).
            let pieces = Piece.allCases.map { learner.known(Skill($0)) }
            return pieces.reduce(0, +) / Double(pieces.count)
        case 4:
            return learner.known(.teamMakeup)
        default:
            return learner.known(.colour)
        }
    }

    /// Level BKT would pick next for this exercise, from the level just played.
    func suggestedLevel(for exercise: PoolExercise, lastLevel: Int) -> Int {
        LevelSelector(config.levels).level(p: levelSkillP(for: exercise), lastLevel: lastLevel,
                                           colour: learner.known(.colour), charcoalIntroSeen: true, wobbly: false)
    }
}
