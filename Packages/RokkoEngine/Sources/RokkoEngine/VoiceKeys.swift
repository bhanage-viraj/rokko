//
//  VoiceKeys.swift
//  Voice line ids used by the games, exactly as in voice_lines.csv. Captions are looked up by these.
//

import RokkoContent

public enum VoiceKeys {
    // Types 1 · 2
    public static func questionPiece(_ p: Piece) -> String { "l1_q_t1_\(p.rawValue)" }
    public static func questionPieceWhite(_ p: Piece) -> String { "l1_q_t1w_\(p.rawValue)" }
    public static func questionAnimal(_ p: Piece) -> String { "l1_q_t2_\(p.animal)" }
    public static func questionAnimalWhite(_ p: Piece) -> String { "l1_q_t2w_\(p.animal)" }
    public static func reward(_ p: Piece) -> String { "l1_rw_\(p.rawValue)" }
    public static func revealPiece(_ p: Piece) -> String { "l1_h3_piece_\(p.rawValue)" }
    public static func revealAnimal(_ p: Piece) -> String { "l1_h3_animal_\(p.animal)" }
    /// Hint 1, said with the clue card: what matches, e.g. "Look at this. The elephant has a tower. The Rook is a tower too."
    public static func hintClue(_ p: Piece) -> String { "l1_h1_match_\(p.rawValue)" }
    public static let hintLookHere = "l1_h2_lookhere"

    // Type 3
    public static let linkIntro = "l1_t3_intro"
    public static func linked(_ p: Piece) -> String { "l1_ln_\(p.rawValue)" }

    // Type 4
    public static func shelfIntro(_ team: ItemColour) -> String { "l1_t4_intro_\(team.rawValue)" }
    /// "One Rook!" when the group is one slot; "Two Rooks!" / "Eight Pawns!" on a full-team shelf.
    public static func shelfCount(_ p: Piece, count: Int = 1) -> String {
        count <= 1 ? "l1_t4_count_\(p.rawValue)" : "l1_t4_count_\(p.rawValue)_\(count)"
    }
    public static let shelfDone = "l1_t4_done"
    /// End of a full-team shelf (16 pieces).
    public static let shelfDoneFullTeam = "l1_t4_done_full"

    // Type 5
    public static let teamsIntro = "l1_t5_intro"
    public static let teamsWhite = "l1_t5_white"
    public static let teamsBlack = "l1_t5_black"
    public static let teamsDone = "l1_t5_done"
    /// Hint 3 for Type 5: "This piece goes to the white team."
    public static func teamsReveal(_ team: ItemColour) -> String { "l1_t5_h3_\(team.rawValue)" }

    // Black team intro: after l1_ch_01–04 (the animals), the black pieces.
    public static let charcoalPieces = "l1_ch_05"

    // Breaks
    public static let breakStart = "l1_br_start"
    public static let breakMove = "l1_br_move"
    public static let breakBreathe = "l1_br_breathe"
    public static let breakQuiet = "l1_br_quiet"
    public static let breakEnd = "l1_br_end"

    // Cheers (said before the line; CheerPicker varies them)
    /// Before a right answer: Types 1–2 reward, Type 3 link, Type 4 count, Type 5 team.
    public static let cheers = ["l1_cheer_yes", "l1_cheer_welldone", "l1_cheer_thatsright",
                                "l1_cheer_goodjob", "l1_cheer_yougotit", "l1_cheer_great"]
    /// Before a finished shelf (Type 4) or both teams (Type 5).
    public static let finishes = ["l1_finish_hooray", "l1_finish_youdidit", "l1_finish_wonderful", "l1_finish_greatwork"]
    /// Calm support after a try that did not fit, said on its own (not when a hint is due). Never "wrong" / "no".
    public static let encouragements = ["l1_enc_okay", "l1_enc_tryagain", "l1_enc_keepgoing",
                                        "l1_enc_youcan", "l1_enc_letstry", "l1_enc_taketime"]
}
