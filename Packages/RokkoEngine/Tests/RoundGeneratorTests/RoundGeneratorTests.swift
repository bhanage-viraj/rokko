//
//  RoundGeneratorTests.swift
//  Every pool round → a valid RoundSpec; same code → same spec; answer slot never repeats.
//

import Foundation
import Testing
import RokkoContent
@testable import RokkoEngine

private enum Fixtures {
    static let content = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("rokko/Content")
    static let pool = try! ExercisePool.load(from: content.appendingPathComponent("Lesson1/exercise_pool.json"))
    static let config = try! EngineConfig.load(from: content.appendingPathComponent("EngineConfig.json"))
    static let generator = RoundGenerator(settings: .init(config))

    static func type(of round: PoolRound) -> Int { pool.exercise(round.exerciseCode)!.type }
}

@Suite("Seeded random")
struct SeededRandomTests {
    @Test func fnvKnownValues() {
        #expect(FNV1a.hash64("") == 0xcbf2_9ce4_8422_2325)
        #expect(FNV1a.hash64("a") == 0xaf63_dc4c_8601_ec8c)
    }

    @Test func splitMixIsStable() {
        var a = SplitMix64(seed: 0), b = SplitMix64(seed: 0)
        #expect(a.next() == 0xe220_a839_7b1d_cdaf)
        _ = b.next()
        #expect(a.next() == b.next())
    }
}

@Suite("RoundGenerator")
struct RoundGeneratorTests {
    @Test func sameCodeSameRound() {
        for round in Fixtures.pool.allRounds {
            let t = Fixtures.type(of: round)
            let a = Fixtures.generator.spec(for: round, type: t)
            let b = Fixtures.generator.spec(for: round, type: t)
            #expect(Self.fingerprint(a) == Self.fingerprint(b), "\(round.id)")
        }
    }

    @Test func everyRoundIsValid() {
        for round in Fixtures.pool.allRounds {
            let spec = Fixtures.generator.spec(for: round, type: Fixtures.type(of: round))
            #expect(spec.id == round.id)
            switch (round.content, spec.body) {
            case (.choice(let c), .choice(let s)):
                #expect(Set(s.cards.map(\.item)) == Set(c.options), "\(round.id)")
                #expect(s.cards[s.answerSlot].item == c.answer && s.cards[s.answerSlot].id == s.answerId, "\(round.id)")
                #expect(Set(s.cards.map(\.id)).count == s.cards.count)
            case (.link(let c), .link(let s)):
                let chars = s.parts.flatMap(\.characters), pieces = s.parts.flatMap(\.pieces)
                #expect(chars.map(\.item).sorted { $0.token < $1.token } == c.characters.sorted { $0.token < $1.token }, "\(round.id)")
                #expect(pieces.map(\.item).sorted { $0.token < $1.token } == c.pieces.sorted { $0.token < $1.token }, "\(round.id)")
                for part in s.parts {
                    let byId = Dictionary(uniqueKeysWithValues: part.pieces.map { ($0.id, $0.item) })
                    for ch in part.characters {
                        let targets = part.matches[ch.id] ?? []
                        #expect(!targets.isEmpty)
                        #expect(targets.allSatisfy { byId[$0]?.piece == ch.item.piece }, "\(round.id)")
                    }
                }
                #expect(s.parts.count == (round.level == 4 ? Fixtures.config.layout.type3Level4Parts : 1))
            case (.shelf(let c), .shelf(let s)):
                // Every slot either prefilled or filled by exactly one figure.
                let team = s.figures.filter { !s.distractorIds.contains($0.id) }
                #expect(s.prefilled.count + team.count == s.slots.count, "\(round.id)")
                #expect(team.allSatisfy { $0.item.colour == c.team })
                let distractors = s.figures.filter { s.distractorIds.contains($0.id) }
                #expect(distractors.isEmpty == c.distractors.isEmpty, "\(round.id)")
                if Fixtures.generator.settings.shelfFullTeamForms.contains(s.form) {
                    // Whole team of 16, as the pool lists it: K Q R R B B N N on top, 8 Pawns below.
                    #expect(s.slots.map(\.piece) == RoundGenerator.fullTeamSlots().map(\.piece), "\(round.id)")
                    #expect(s.slots.filter { $0.tier == 1 }.allSatisfy { $0.piece == .pawn })
                    #expect(team.count == c.toPlace.count && s.prefilled.count == c.prefilled.count, "\(round.id)")
                    #expect(distractors.count == c.distractors.count, "\(round.id)")
                } else {
                    // One slot per piece.
                    #expect(s.slots.map(\.piece) == RoundGenerator.teamSet)
                    #expect(Set(team.map(\.item.piece)).count == team.count, "\(round.id)")
                    #expect(Set(distractors.map(\.item.piece)).count == distractors.count, "\(round.id)")
                }
                for p in Piece.allCases {
                    let free = s.slots.filter { $0.piece == p && s.prefilled[$0.id] == nil }.count
                    let placing = team.filter { $0.item.piece == p }.count
                    #expect(free == placing, "\(round.id) \(p)")
                    #expect(s.countKeys[p] == VoiceKeys.shelfCount(p, count: s.slots.filter { $0.piece == p }.count))
                }
            case (.teams(let c), .teams(let s)):
                #expect(s.slots.count == 2 * RoundGenerator.teamSet.count)
                let figures = s.batches.flatMap { $0 }
                #expect(!figures.isEmpty, "\(round.id)")
                #expect(Set(figures.map(\.item)).count == figures.count, "\(round.id)")
                #expect(s.prefilled.count + figures.count == s.slots.count, "\(round.id)")
                let half = Fixtures.config.layout.type5BatchSize / 2
                for batch in s.batches {
                    #expect(batch.count <= Fixtures.config.layout.type5BatchSize)
                    #expect(batch.filter { $0.item.colour == .white }.count <= half)
                    #expect(batch.filter { $0.item.colour == .black }.count <= half)
                }
                for team in [ItemColour.white, .black] {
                    for p in Piece.allCases {
                        let free = s.slots.filter { $0.team == team && $0.piece == p && s.prefilled[$0.id] == nil }.count
                        let placing = figures.filter { $0.item.colour == team && $0.item.piece == p }.count
                        #expect(free == placing, "\(round.id) \(team) \(p)")
                    }
                }
            default:
                Issue.record("\(round.id): body does not match content")
            }
        }
    }

    @Test func pieceShelfKeepsWholeTeam() {
        // Black shelf (piece figures): 2 Rooks, 2 Bishops, 2 Knights and 8 Pawns, as in the pool.
        let ex = Fixtures.pool.exercise("001-3-04-04")!
        for level in 1...3 {
            let round = ex.rounds(level: level)[0]
            guard case .shelf(let s) = Fixtures.generator.spec(for: round, type: 4).body,
                  case .shelf(let c) = round.content else { Issue.record("not a shelf"); continue }
            #expect(s.slots.count == 16)
            for p in Piece.allCases { #expect(s.slots.filter { $0.piece == p }.count == p.countInTeam) }
            #expect(s.figures.count == c.toPlace.count, "\(round.id)")
            #expect(s.doneKey == VoiceKeys.shelfDoneFullTeam)
            #expect(s.countKeys[.rook] == "l1_t4_count_rook_2" && s.countKeys[.pawn] == "l1_t4_count_pawn_8")
            #expect(s.countKeys[.king] == "l1_t4_count_king")
        }
        // White shelf (character figures) still shows one of each.
        let white = Fixtures.pool.exercise("001-3-04-03")!.rounds(level: 1)[0]
        guard case .shelf(let w) = Fixtures.generator.spec(for: white, type: 4).body else { Issue.record("not a shelf"); return }
        #expect(w.slots.count == 6)
        #expect(w.doneKey == VoiceKeys.shelfDone)
    }

    @Test func onePerPiecePrefersToPlace() {
        let w = { (p: Piece) in Item(.white, .character, p) }
        let r = RoundGenerator.onePerPiece(toPlace: [w(.rook), w(.rook), w(.king), w(.pawn), w(.pawn)],
                                           prefilled: [w(.rook), w(.queen), w(.pawn), w(.bishop), w(.bishop), w(.knight)])
        #expect(r.toPlace == [w(.rook), w(.king), w(.pawn)])
        #expect(r.prefilled == [w(.queen), w(.bishop), w(.knight)])
    }

    @Test func answerSlotNeverRepeats() {
        var previous: Int?
        var changed = 0
        for round in Fixtures.pool.allRounds {
            let spec = Fixtures.generator.spec(for: round, type: Fixtures.type(of: round), previousAnswerSlot: previous)
            guard case .choice(let c) = spec.body else { continue }
            if let previous { #expect(c.answerSlot != previous, "\(round.id)") }
            let plain = Fixtures.generator.spec(for: round, type: Fixtures.type(of: round))
            if case .choice(let p) = plain.body, p.answerSlot != c.answerSlot { changed += 1 }
            previous = c.answerSlot
        }
        #expect(changed > 0)
    }

    @Test func positionsActuallyVary() {
        // The pool lists the answer first; the shuffle must not leave it there every time.
        let slots = Fixtures.pool.allRounds.compactMap { r -> Int? in
            guard case .choice(let c) = Fixtures.generator.spec(for: r, type: Fixtures.type(of: r)).body else { return nil }
            return c.answerSlot
        }
        #expect(Set(slots).count >= 4)
        #expect(Double(slots.filter { $0 == 0 }.count) / Double(slots.count) < 0.5)
    }

    @Test func questionKeys() {
        let king = Fixtures.pool.exercise("001-1-01-01")!
        let l1 = Fixtures.generator.spec(for: king.rounds(level: 1)[0], type: 1)
        let l5 = Fixtures.generator.spec(for: king.rounds(level: 5)[0], type: 1)
        #expect(l1.introKey == "l1_q_t1_king")
        #expect(l5.introKey == "l1_q_t1w_king")
        let lion = Fixtures.pool.exercise("001-1-02-04")!
        #expect(Fixtures.generator.spec(for: lion.rounds(level: 1)[0], type: 2).introKey == "l1_q_t2_lion")
    }

    static func fingerprint(_ s: RoundSpec) -> String {
        switch s.body {
        case .choice(let c): return c.cards.map { "\($0.id)=\($0.item)" }.joined(separator: ",") + "|\(c.answerSlot)"
        case .link(let l): return l.parts.map { p in
            p.characters.map(\.item.token).joined(separator: ",") + "/" + p.pieces.map(\.item.token).joined(separator: ",")
        }.joined(separator: "#")
        case .shelf(let sh): return sh.figures.map(\.item.token).joined(separator: ",") + "|" + sh.prefilled.keys.sorted().joined(separator: ",")
        case .teams(let t): return t.batches.map { $0.map(\.item.token).joined(separator: ",") }.joined(separator: "#")
        }
    }
}
