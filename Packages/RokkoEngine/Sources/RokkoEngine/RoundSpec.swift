//
//  RoundSpec.swift
//  Everything a scene needs to draw one round, already decided: which cards, in which order,
//  which slots are prefilled, which batches arrive. Scenes draw this; view models judge answers.
//

import RokkoContent

/// One card or figure on screen. `id` is stable for the round ("c0", "f3", …).
public struct Card: Identifiable, Hashable, Sendable {
    public let id: String
    public let item: Item
}

public struct RoundSpec: Sendable, Identifiable {
    /// Full code `LLL-M-TT-EE-V-III`.
    public let id: String
    public let type: Int
    public let level: Int
    /// Voice key for the opening line (question or instruction).
    public let introKey: String
    public let body: Body

    public enum Body: Sendable {
        case choice(ChoiceRound)
        case link(LinkRound)
        case shelf(ShelfRound)
        case teams(TeamsRound)
    }
}

// MARK: - Types 1 · 2

public struct ChoiceRound: Sendable {
    /// The large figure at the top.
    public let shown: Item
    /// Answer cards, left to right.
    public let cards: [Card]
    public let answerId: String
    /// Index of the answer in `cards`.
    public let answerSlot: Int
    /// "I'm the King!"
    public let correctKey: String
    /// "This is the King." / "This is the lion." (hint 3)
    public let revealKey: String
}

// MARK: - Type 3

public struct LinkRound: Sendable {
    public enum Layout: Sendable {
        /// Characters top row, pieces bottom row (levels 1–4).
        case rows
        /// White pieces top, white characters, black characters, black pieces bottom (level 5).
        case colourBands
        /// Shaded characters in the middle; white pieces top, black pieces bottom (level 6).
        case shaded
    }

    public let layout: Layout
    /// Shown one after another; level 4 has two parts of 5 pairs, every other level has one.
    public let parts: [LinkPart]
}

public struct LinkPart: Sendable {
    public let characters: [Card]
    public let pieces: [Card]
    /// Character id → the piece id(s) it links to (two at level 6).
    public let matches: [String: Set<String>]

    public var linkCount: Int { matches.values.reduce(0) { $0 + $1.count } }
}

// MARK: - Type 4

public struct ShelfSlot: Identifiable, Hashable, Sendable {
    public let id: String
    public let piece: Piece
    /// 0 = top tier. One-of-each shelf: one tier of K Q R B N P. Full-team shelf: K Q R R B B N N on 0, 8 Pawns on 1.
    public let tier: Int
    public let index: Int
}

public struct ShelfRound: Sendable {
    public let team: ItemColour
    public let form: ItemForm
    /// 6 slots (one per piece: K Q R B N P), or 16 for a full-team shelf.
    public let slots: [ShelfSlot]
    /// Slot id → figure already standing there.
    public let prefilled: [String: Item]
    /// Figures waiting below, in display order (team figures and distractors mixed).
    public let figures: [Card]
    /// Figures of the other colour (level 6). They never go on the shelf.
    public let distractorIds: Set<String>
    public let countKeys: [Piece: String]
    public let doneKey: String
}

// MARK: - Type 5

public struct HouseSlot: Identifiable, Hashable, Sendable {
    public let id: String
    public let team: ItemColour
    public let piece: Piece
    /// Always 0: one row of K Q R B N P.
    public let row: Int
    public let index: Int
}

public struct TeamsRound: Sendable {
    public let whiteKing: Item
    public let blackKing: Item
    /// 6 slots per house (one per piece); white first.
    public let slots: [HouseSlot]
    /// Slot id → figure already in the house (kings included).
    public let prefilled: [String: Item]
    /// Figures arrive in these batches (2 white + 2 black each, last one may be smaller).
    public let batches: [[Card]]
    public let whiteKey: String
    public let blackKey: String
    public let doneKey: String
}
