//
//  ExercisePool.swift
//  Models for Content/Lesson1/exercise_pool.json: every round of Lesson 1, imported from
//  Lesson_1_Exercise_Pool with Tools/import_exercise_pool.py. The app never invents a round.
//

import Foundation

public struct ExercisePool: Decodable, Sendable {
    public let source: String
    public let exercises: [PoolExercise]

    public static func load(from url: URL) throws -> ExercisePool {
        try JSONDecoder().decode(ExercisePool.self, from: Data(contentsOf: url))
    }

    public func exercise(_ code: String) -> PoolExercise? {
        exercises.first { $0.code == code }
    }

    /// Every round in pool order.
    public var allRounds: [PoolRound] {
        exercises.flatMap { ex in ex.levelNumbers.flatMap { ex.rounds(level: $0) } }
    }
}

public struct PoolExercise: Decodable, Sendable, Identifiable {
    /// `LLL-M-TT-EE`
    public let code: String
    public let type: Int
    private let levels: [String: PoolLevel]

    public var id: String { code }
    public var exerciseCode: ExerciseCode? { ExerciseCode(code) }

    public var levelNumbers: [Int] { levels.keys.compactMap(Int.init).sorted() }

    public func level(_ n: Int) -> PoolLevel? { levels[String(n)] }

    public func rounds(level n: Int) -> [PoolRound] { level(n)?.rounds ?? [] }
}

public struct PoolLevel: Decodable, Sendable {
    /// How many different rounds the rules allow at this level (the pool holds a subset).
    public let possibleVariants: Int
    public let rounds: [PoolRound]
}

public struct PoolRound: Decodable, Sendable, Identifiable, Hashable {
    /// Full code `LLL-M-TT-EE-V-III`. Also the generator seed.
    public let id: String
    public let level: Int
    /// 1-based position inside its level.
    public let variant: Int
    public let content: RoundContent
    public let note: String?

    public var exerciseCode: String { String(id.split(separator: "-").prefix(4).joined(separator: "-")) }

    private enum Keys: String, CodingKey {
        case id, level, variant, note
        case shown, options, answer
        case characters, pieces, pairs
        case shelf, toPlace, prefilled, distractors
        case kings
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        level = try c.decode(Int.self, forKey: .level)
        variant = try c.decode(Int.self, forKey: .variant)
        note = try c.decodeIfPresent(String.self, forKey: .note)

        if c.contains(.shown) {
            content = .choice(ChoiceContent(shown: try c.decode(Item.self, forKey: .shown),
                                            options: try c.decode([Item].self, forKey: .options),
                                            answer: try c.decode(Item.self, forKey: .answer)))
        } else if c.contains(.pairs) {
            content = .link(LinkContent(characters: try c.decode([Item].self, forKey: .characters),
                                        pieces: try c.decode([Item].self, forKey: .pieces),
                                        pairs: try c.decode([LinkPair].self, forKey: .pairs)))
        } else if c.contains(.shelf) {
            content = .shelf(ShelfContent(team: try c.decode(ItemColour.self, forKey: .shelf),
                                          toPlace: try c.decode([Item].self, forKey: .toPlace),
                                          prefilled: try c.decode([Item].self, forKey: .prefilled),
                                          distractors: try c.decode([Item].self, forKey: .distractors)))
        } else if c.contains(.kings) {
            let kings = try c.decode([String: Item].self, forKey: .kings)
            let pre = try c.decode([String: [Item]].self, forKey: .prefilled)
            guard let wk = kings["white"], let bk = kings["black"] else {
                throw DecodingError.dataCorruptedError(forKey: .kings, in: c, debugDescription: "kings needs white and black")
            }
            content = .teams(TeamsContent(whiteKing: wk, blackKing: bk,
                                          toPlace: try c.decode([Item].self, forKey: .toPlace),
                                          prefilledWhite: pre["white"] ?? [],
                                          prefilledBlack: pre["black"] ?? []))
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Unknown round shape \(id)")
        }
    }

    public static func == (a: PoolRound, b: PoolRound) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

public enum RoundContent: Sendable, Hashable {
    /// Types 1 and 2: tap the matching card.
    case choice(ChoiceContent)
    /// Type 3: drag each character onto its piece.
    case link(LinkContent)
    /// Type 4: fill one team's shelf.
    case shelf(ShelfContent)
    /// Type 5: sort figures into the white and black houses.
    case teams(TeamsContent)
}

public struct ChoiceContent: Sendable, Hashable {
    public let shown: Item
    /// Pool order lists the answer first; never show this order.
    public let options: [Item]
    public let answer: Item
}

public struct LinkPair: Decodable, Sendable, Hashable {
    public let character: Item
    /// One piece, or two (white and black) for a shaded character at level 6.
    public let pieces: [Item]
}

public struct LinkContent: Sendable, Hashable {
    public let characters: [Item]
    public let pieces: [Item]
    public let pairs: [LinkPair]
}

public struct ShelfContent: Sendable, Hashable {
    public let team: ItemColour
    public let toPlace: [Item]
    public let prefilled: [Item]
    /// Other-colour figures (level 6). They never go on the shelf.
    public let distractors: [Item]
}

public struct TeamsContent: Sendable, Hashable {
    public let whiteKing: Item
    public let blackKing: Item
    public let toPlace: [Item]
    public let prefilledWhite: [Item]
    public let prefilledBlack: [Item]
}
