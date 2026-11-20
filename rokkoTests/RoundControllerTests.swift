//
//  RoundControllerTests.swift
//  Plays every pool round through the real view model and scene (no view on screen):
//  right answers finish the round, wrong answers never do, captions are the recorded lines.
//

import Testing
import SpriteKit
import RokkoContent
import RokkoEngine
@testable import rokko

@MainActor
struct RoundControllerTests {
    let library: ContentLibrary
    let motion: SceneMotion

    init() throws {
        library = try ContentLibrary(bundle: .main)
        motion = SceneMotion(library.config, calm: true, reduceMotion: true)
    }

    private func controller(_ round: PoolRound) -> RoundController {
        let type = library.pool.exercise(round.exerciseCode)!.type
        let spec = library.generator.spec(for: round, type: type)
        return RoundController(spec: spec, library: library, motion: motion, instantFeedback: true)
    }

    @Test func everyRoundCanBeFinished() {
        for round in library.pool.allRounds {
            let c = controller(round)
            #expect(c.caption == library.caption(c.spec.introKey), "\(round.id) intro caption")
            playPerfectly(c)
            #expect(c.isFinished, "\(round.id) did not finish")
            #expect(c.answers.allSatisfy { $0.outcome == .right }, "\(round.id)")
        }
    }

    @Test func choiceWrongThenRight() throws {
        let round = try #require(library.pool.exercise("001-1-01-01")?.rounds(level: 3).first)
        let c = controller(round)
        guard case .choice(let r) = c.spec.body else { Issue.record("not a choice round"); return }
        let wrong = r.cards.first { $0.id != r.answerId }!
        c.scene(c.scene, didReport: .tap(wrong.id))
        #expect(!c.isFinished)
        #expect(c.answers.last?.outcome == .tryAgain)
        // A supporting line, said on its own.
        let support = VoiceKeys.encouragements.compactMap { library.caption($0) }
        #expect(support.contains { c.caption == $0 }, "no supporting line: \(c.caption ?? "nil")")
        // Tapping the same sunk card again is ignored.
        c.scene(c.scene, didReport: .tap(wrong.id))
        #expect(c.answers.count == 1)
        c.scene(c.scene, didReport: .tap(r.answerId))
        #expect(c.isFinished)
        #expect(c.caption?.hasSuffix("I\u{2019}m the King!") == true)
    }

    @Test func linkWrongPieceSpringsBack() throws {
        let round = try #require(library.pool.exercise("001-3-03-01")?.rounds(level: 1).first)
        let c = controller(round)
        guard case .link(let r) = c.spec.body else { return }
        let part = r.parts[0]
        let ch = part.characters[0]
        let wrong = part.pieces.first { !(part.matches[ch.id] ?? []).contains($0.id) }!
        c.scene(c.scene, didReport: .drop(ch.id, target: wrong.id))
        #expect(c.answers.last?.outcome == .tryAgain)
        c.scene(c.scene, didReport: .drop(ch.id, target: nil))
        #expect(c.answers.count == 1, "a drop on nothing is not an answer")
        #expect(!c.isFinished)
    }

    @Test func linkPieceOntoCharacterCounts() throws {
        let round = try #require(library.pool.exercise("001-3-03-01")?.rounds(level: 1).first)
        let c = controller(round)
        guard case .link(let r) = c.spec.body else { return }
        let part = r.parts[0]
        let ch = part.characters[0]
        let right = try #require(part.matches[ch.id]?.sorted().first)
        let wrongCh = try #require(part.characters.first { !($0.id == ch.id) && !(part.matches[$0.id] ?? []).contains(right) })
        c.scene(c.scene, didReport: .drop(right, target: wrongCh.id))
        #expect(c.answers.last?.outcome == .tryAgain, "piece on the wrong animal")
        c.scene(c.scene, didReport: .drop(right, target: nil))
        #expect(c.answers.count == 1, "a piece dropped on nothing is not an answer")
        c.scene(c.scene, didReport: .drop(right, target: ch.id))
        #expect(c.answers.last?.outcome == .right, "piece on its animal links them")
    }

    @Test func linkHintsFollowTheMissedPair() throws {
        let round = try #require(library.pool.exercise("001-3-03-01")?.rounds(level: 1).first)
        let c = controller(round)
        guard case .link(let r) = c.spec.body else { return }
        let part = r.parts[0]
        // Not the first animal on screen: the old hints always went to that one.
        let ch = try #require(part.characters.dropFirst().first { $0.item.piece != part.characters[0].item.piece })
        let wrong = try #require(part.pieces.first { !(part.matches[ch.id] ?? []).contains($0.id) })
        for _ in 0..<8 where c.results.isEmpty {
            c.scene(c.scene, didReport: .drop(ch.id, target: wrong.id))
        }
        let shown = try #require(c.results.first, "hint 3 should show the answer")
        #expect(shown.skill == Skill(ch.item.piece), "the hint showed another pair")
        #expect(!shown.correct)
    }

    @Test func shelfDistractorNeverGoesOn() throws {
        let round = try #require(library.pool.exercise("001-3-04-03")?.rounds(level: 6).first)
        let c = controller(round)
        guard case .shelf(let r) = c.spec.body else { return }
        let distractor = try #require(r.figures.first { r.distractorIds.contains($0.id) })
        let slot = try #require(r.slots.first { $0.piece == distractor.item.piece && r.prefilled[$0.id] == nil })
        c.scene(c.scene, didReport: .drop(distractor.id, target: slot.id))
        #expect(c.answers.last?.outcome == .tryAgain)
        playPerfectly(c)
        #expect(c.isFinished)
        #expect(c.caption?.hasSuffix("All six pieces are on the shelf!") == true)
    }

    @Test func teamsWrongHouse() throws {
        let round = try #require(library.pool.exercise("001-3-05-06")?.rounds(level: 1).first)
        let c = controller(round)
        guard case .teams(let r) = c.spec.body else { return }
        let fig = r.batches[0][0]
        let wrongHouse = fig.item.colour == .white ? TeamsScene.blackHouse : TeamsScene.whiteHouse
        c.scene(c.scene, didReport: .drop(fig.id, target: wrongHouse))
        #expect(c.answers.last?.outcome == .tryAgain)
        playPerfectly(c)
        #expect(c.isFinished)
        #expect(c.caption?.hasSuffix("All the pieces are with their team!") == true)
    }

    // MARK: Perfect play

    private func playPerfectly(_ c: RoundController) {
        switch c.spec.body {
        case .choice(let r):
            c.scene(c.scene, didReport: .tap(r.answerId))
        case .link(let r):
            for part in r.parts {
                for ch in part.characters {
                    for piece in (part.matches[ch.id] ?? []).sorted() {
                        c.scene(c.scene, didReport: .drop(ch.id, target: piece))
                    }
                }
            }
        case .shelf(let r):
            var used = Set(r.prefilled.keys)
            for fig in r.figures where !r.distractorIds.contains(fig.id) {
                guard let slot = r.slots.first(where: { $0.piece == fig.item.piece && !used.contains($0.id) }) else { continue }
                used.insert(slot.id)
                c.scene(c.scene, didReport: .drop(fig.id, target: slot.id))
            }
        case .teams(let r):
            for batch in r.batches {
                for fig in batch {
                    c.scene(c.scene, didReport: .drop(fig.id, target: fig.item.colour == .white ? TeamsScene.whiteHouse : TeamsScene.blackHouse))
                }
            }
        }
    }
}
