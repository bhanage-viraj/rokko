//
//  RoundGenerator.swift
//  Pool round → RoundSpec. Which cards appear comes from the pool; the seed (FNV-1a of the full
//  code) only sets positions, figure order and batches. Same code → same RoundSpec, always.
//

import RokkoContent

public struct RoundGenerator: Sendable {
    public struct Settings: Sendable {
        public var avoidSameAnswerSlot: Bool
        public var type5BatchSize: Int
        public var type3Level4Parts: Int
        /// Type 4 shelves in these forms keep the whole team of 16; others keep one of each.
        public var shelfFullTeamForms: Set<ItemForm>

        public init(avoidSameAnswerSlot: Bool, type5BatchSize: Int, type3Level4Parts: Int,
                    shelfFullTeamForms: Set<ItemForm> = []) {
            self.avoidSameAnswerSlot = avoidSameAnswerSlot
            self.type5BatchSize = type5BatchSize
            self.type3Level4Parts = type3Level4Parts
            self.shelfFullTeamForms = shelfFullTeamForms
        }

        public init(_ config: EngineConfig) {
            self.init(avoidSameAnswerSlot: config.generator.avoidSameAnswerSlot,
                      type5BatchSize: config.layout.type5BatchSize,
                      type3Level4Parts: config.layout.type3Level4Parts,
                      shelfFullTeamForms: Set(config.generator.shelfFullTeamForms ?? []))
        }
    }

    public let settings: Settings

    public init(settings: Settings) { self.settings = settings }

    /// - Parameter previousAnswerSlot: where the answer was in the previous choice round, if any.
    public func spec(for round: PoolRound, type: Int, previousAnswerSlot: Int? = nil) -> RoundSpec {
        var rng = SplitMix64(code: round.id)
        switch round.content {
        case .choice(let c):
            return choice(round, type: type, c, &rng, previousAnswerSlot)
        case .link(let c):
            return link(round, type: type, c, &rng)
        case .shelf(let c):
            return shelf(round, type: type, c, &rng)
        case .teams(let c):
            return teams(round, type: type, c, &rng)
        }
    }

    // MARK: Types 1 · 2

    private func choice(_ round: PoolRound, type: Int, _ c: ChoiceContent,
                        _ rng: inout SplitMix64, _ previous: Int?) -> RoundSpec {
        var order = c.options.seededShuffle(&rng)
        if settings.avoidSameAnswerSlot, let previous, order.count > 1,
           let slot = order.firstIndex(of: c.answer), slot == previous {
            order.swapAt(slot, (slot + 1 + rng.index(below: order.count - 1)) % order.count)
        }
        let cards = order.enumerated().map { Card(id: "c\($0.offset)", item: $0.element) }
        let slot = order.firstIndex(of: c.answer)!
        let piece = c.answer.piece
        let coloured = round.level >= 5
        let intro: String = c.answer.form == .piece
            ? (coloured ? VoiceKeys.questionPieceWhite(piece) : VoiceKeys.questionPiece(piece))
            : (coloured ? VoiceKeys.questionAnimalWhite(piece) : VoiceKeys.questionAnimal(piece))
        let reveal = c.answer.form == .piece ? VoiceKeys.revealPiece(piece) : VoiceKeys.revealAnimal(piece)
        return RoundSpec(id: round.id, type: type, level: round.level, introKey: intro,
                         body: .choice(ChoiceRound(shown: c.shown, cards: cards, answerId: cards[slot].id,
                                                   answerSlot: slot, correctKey: VoiceKeys.reward(piece),
                                                   revealKey: reveal)))
    }

    // MARK: Type 3

    private func link(_ round: PoolRound, type: Int, _ c: LinkContent, _ rng: inout SplitMix64) -> RoundSpec {
        let layout: LinkRound.Layout = round.level == 6 ? .shaded : (round.level == 5 ? .colourBands : .rows)
        let pairs = c.pairs.seededShuffle(&rng)
        let partCount = round.level == 4 ? max(1, settings.type3Level4Parts) : 1
        let size = (pairs.count + partCount - 1) / partCount
        var parts: [LinkPart] = []
        var charN = 0, pieceN = 0
        for start in stride(from: 0, to: pairs.count, by: size) {
            let group = Array(pairs[start..<min(start + size, pairs.count)])
            var chars: [Card] = []
            var pieceCards: [Card] = []
            var matches: [String: Set<String>] = [:]
            for pair in group {
                let ch = Card(id: "ch\(charN)", item: pair.character); charN += 1
                chars.append(ch)
                var ids = Set<String>()
                for p in pair.pieces {
                    let pc = Card(id: "pc\(pieceN)", item: p); pieceN += 1
                    pieceCards.append(pc)
                    ids.insert(pc.id)
                }
                matches[ch.id] = ids
            }
            // Characters keep the shuffled pair order; pieces get their own order.
            parts.append(LinkPart(characters: chars, pieces: pieceCards.seededShuffle(&rng), matches: matches))
        }
        return RoundSpec(id: round.id, type: type, level: round.level, introKey: VoiceKeys.linkIntro,
                         body: .link(LinkRound(layout: layout, parts: parts)))
    }

    // MARK: One of each piece

    /// Shelves (one-of-each forms) and houses hold one figure per piece: King, Queen, Rook, Bishop, Knight, Pawn.
    static let teamSet: [Piece] = [.king, .queen, .rook, .bishop, .knight, .pawn]

    /// Keeps one figure per piece. The pool still lists a full team of 16; a piece the pool
    /// asks the child to place stays to place, otherwise it stays prefilled.
    static func onePerPiece(toPlace: [Item], prefilled: [Item]) -> (toPlace: [Item], prefilled: [Item]) {
        let place = uniquePieces(toPlace)
        let placing = Set(place.map(\.piece))
        return (place, uniquePieces(prefilled).filter { !placing.contains($0.piece) })
    }

    static func uniquePieces(_ items: [Item]) -> [Item] {
        var seen = Set<Piece>()
        return items.filter { seen.insert($0.piece).inserted }
    }

    // MARK: Type 4

    /// The whole team on two tiers: K Q R R B B N N on top, the 8 Pawns below.
    static func fullTeamSlots() -> [ShelfSlot] {
        let back = teamSet.filter { $0 != .pawn }.flatMap { Array(repeating: $0, count: $0.countInTeam) }
        let pawns = Array(repeating: Piece.pawn, count: Piece.pawn.countInTeam)
        return (back.map { (0, $0) } + pawns.map { (1, $0) })
            .enumerated()
            .map { n, e in ShelfSlot(id: "s\(n)", piece: e.1, tier: e.0, index: e.0 == 0 ? n : n - back.count) }
    }

    private func shelf(_ round: PoolRound, type: Int, _ c: ShelfContent, _ rng: inout SplitMix64) -> RoundSpec {
        let form = (c.toPlace.first ?? c.prefilled.first)?.form ?? .character
        let fullTeam = settings.shelfFullTeamForms.contains(form)
        let slots = fullTeam
            ? Self.fullTeamSlots()
            : Self.teamSet.enumerated().map { ShelfSlot(id: "s\($0.offset)", piece: $0.element, tier: 0, index: $0.offset) }
        let team = fullTeam ? (toPlace: c.toPlace, prefilled: c.prefilled)
                            : Self.onePerPiece(toPlace: c.toPlace, prefilled: c.prefilled)

        var prefilled: [String: Item] = [:]
        for item in team.prefilled {
            if let slot = slots.first(where: { $0.piece == item.piece && prefilled[$0.id] == nil }) { prefilled[slot.id] = item }
        }
        let distractors = fullTeam ? c.distractors : Self.uniquePieces(c.distractors)
        let tagged = team.toPlace.map { ($0, false) } + distractors.map { ($0, true) }
        let order = tagged.seededShuffle(&rng)
        var figures: [Card] = []
        var distractorIds = Set<String>()
        for (i, (item, isDistractor)) in order.enumerated() {
            let card = Card(id: "f\(i)", item: item)
            figures.append(card)
            if isDistractor { distractorIds.insert(card.id) }
        }
        let countKeys = Dictionary(uniqueKeysWithValues: Piece.allCases.map { p in
            (p, VoiceKeys.shelfCount(p, count: slots.filter { $0.piece == p }.count))
        })
        return RoundSpec(id: round.id, type: type, level: round.level, introKey: VoiceKeys.shelfIntro(c.team),
                         body: .shelf(ShelfRound(team: c.team, form: form, slots: slots, prefilled: prefilled,
                                                 figures: figures, distractorIds: distractorIds,
                                                 countKeys: countKeys,
                                                 doneKey: fullTeam ? VoiceKeys.shelfDoneFullTeam : VoiceKeys.shelfDone)))
    }

    // MARK: Type 5

    private func teams(_ round: PoolRound, type: Int, _ c: TeamsContent, _ rng: inout SplitMix64) -> RoundSpec {
        var slots: [HouseSlot] = []
        for team in [ItemColour.white, .black] {
            for (i, p) in Self.teamSet.enumerated() {
                slots.append(HouseSlot(id: "\(team.rawValue.prefix(1))\(i)", team: team, piece: p, row: 0, index: i))
            }
        }
        let white = Self.onePerPiece(toPlace: c.toPlace.filter { $0.colour == .white }, prefilled: c.prefilledWhite)
        let black = Self.onePerPiece(toPlace: c.toPlace.filter { $0.colour == .black }, prefilled: c.prefilledBlack)
        var prefilled: [String: Item] = [:]
        func place(_ item: Item, team: ItemColour) {
            if let slot = slots.first(where: { $0.team == team && $0.piece == item.piece && prefilled[$0.id] == nil }) {
                prefilled[slot.id] = item
            }
        }
        place(c.whiteKing, team: .white)
        place(c.blackKing, team: .black)
        white.prefilled.forEach { place($0, team: .white) }
        black.prefilled.forEach { place($0, team: .black) }

        // Batches: half white, half black each; order inside a batch shuffled.
        var whites = white.toPlace.seededShuffle(&rng)
        var blacks = black.toPlace.seededShuffle(&rng)
        let perTeam = max(1, settings.type5BatchSize / 2)
        var batches: [[Card]] = []
        var n = 0
        while !whites.isEmpty || !blacks.isEmpty {
            var batch: [Item] = []
            batch += whites.prefix(perTeam); whites.removeFirst(min(perTeam, whites.count))
            batch += blacks.prefix(perTeam); blacks.removeFirst(min(perTeam, blacks.count))
            batches.append(batch.seededShuffle(&rng).map { item in
                defer { n += 1 }
                return Card(id: "f\(n)", item: item)
            })
        }
        return RoundSpec(id: round.id, type: type, level: round.level, introKey: VoiceKeys.teamsIntro,
                         body: .teams(TeamsRound(whiteKing: c.whiteKing, blackKing: c.blackKing, slots: slots,
                                                 prefilled: prefilled, batches: batches,
                                                 whiteKey: VoiceKeys.teamsWhite, blackKey: VoiceKeys.teamsBlack,
                                                 doneKey: VoiceKeys.teamsDone)))
    }
}
