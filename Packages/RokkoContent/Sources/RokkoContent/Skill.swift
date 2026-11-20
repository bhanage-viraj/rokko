//
//  Skill.swift
//  The 8 skills BKT tracks in Lesson 1 (docs/ENGINE.md §1). Types 1 and 2 share one score per piece.
//

public enum Skill: String, CaseIterable, Codable, Sendable, Hashable {
    case king, queen, rook, bishop, knight, pawn
    /// Telling the white and black teams apart (Type 5, and black-twin picks at Types 1 · 2 level 6).
    case colour
    /// Knowing what a team is made of (Type 4, once per finished shelf).
    case teamMakeup

    public init(_ piece: Piece) {
        switch piece {
        case .king: self = .king
        case .queen: self = .queen
        case .rook: self = .rook
        case .bishop: self = .bishop
        case .knight: self = .knight
        case .pawn: self = .pawn
        }
    }
}
