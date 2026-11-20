//
//  Item.swift
//  One card / figure in a round: colour + form + piece, written `<colour>.<form>.<piece>`
//  in exercise_pool.json (e.g. `white.character.king`, `black.piece.pawn`, `shaded.character.rook`).
//

/// The six chess pieces, in story order.
public enum Piece: String, CaseIterable, Codable, Sendable, Hashable {
    case king, queen, rook, bishop, knight, pawn

    /// The animal that becomes this piece (skills.json).
    public var animal: String {
        switch self {
        case .king: "lion"
        case .queen: "lioness"
        case .rook: "elephant"
        case .bishop: "kangaroo"
        case .knight: "horse"
        case .pawn: "squirrel"
        }
    }

    /// "King", as shown to the child.
    public var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// How many of this piece one team has.
    public var countInTeam: Int {
        switch self {
        case .king, .queen: 1
        case .rook, .bishop, .knight: 2
        case .pawn: 8
        }
    }
}

/// White (ivory), black (charcoal), or shaded (colour hidden, Type 3 level 6).
public enum ItemColour: String, Codable, Sendable, Hashable {
    case white, black, shaded
}

/// Animal character or chess piece.
public enum ItemForm: String, Codable, Sendable, Hashable {
    case character, piece
}

public struct Item: Hashable, Sendable, Codable, CustomStringConvertible {
    public let colour: ItemColour
    public let form: ItemForm
    public let piece: Piece

    public init(_ colour: ItemColour, _ form: ItemForm, _ piece: Piece) {
        self.colour = colour
        self.form = form
        self.piece = piece
    }

    /// Parses `<colour>.<form>.<piece>`.
    public init?(token: String) {
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count == 3,
              let colour = ItemColour(rawValue: parts[0]),
              let form = ItemForm(rawValue: parts[1]),
              let piece = Piece(rawValue: parts[2]) else { return nil }
        self.init(colour, form, piece)
    }

    public var token: String { "\(colour.rawValue).\(form.rawValue).\(piece.rawValue)" }
    public var description: String { token }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let item = Item(token: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Bad item token \(raw)"))
        }
        self = item
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(token)
    }
}
