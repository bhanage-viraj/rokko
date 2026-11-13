//
//  RokkoTheme.swift
//  Design tokens from docs/DESIGN_SYSTEM.md ("Misty Clearing").
//  One colour, one meaning. Never use raw hex outside this file.
//

import SwiftUI
import UIKit

// MARK: - Colour

enum RokkoColor {
    // DESIGN_SYSTEM.md tokens
    static let paper    = Color(hex: 0xF4F0E3)   // child screens background, Calm surface
    static let mistBlue = Color(hex: 0xDCE7EA)   // Guardian screens only
    static let card     = Color(hex: 0xFBF8EF)   // cards, bars, dialogs
    static let cardEdge = Color(hex: 0xDAD3BD)   // card border (3 pt)
    static let leaf     = Color(hex: 0x2F4A3E)   // primary buttons (Next, Done)
    static let ink      = Color(hex: 0x2D3A31)   // text
    static let inkSoft  = Color(hex: 0x5D6A5F)   // secondary text
    static let honey    = Color(hex: 0xE2B24A)   // hints, glows, arrow, clue edge, step numbers
    static let moss     = Color(hex: 0x5E9A5A)   // correct ring, link lines
    static let lilac    = Color(hex: 0xA597D2)   // try again (dashed outline only)
    static let sageDone = Color(hex: 0xC3D5AC)   // finished path steps
    static let teal     = Color(hex: 0x4A7890)   // Guardian labels, hold rings
    static let bark     = Color(hex: 0x5B4636)   // character name labels

    // Guardian surface edges and washes, from the hi-fi canvas and the first-run prototype.
    static let mistEdge      = Color(hex: 0xBCD0D7)   // Guardian card / label border
    static let mistEdgeSoft  = Color(hex: 0xCFDCE0)   // Guardian list-row border
    static let mistTrack     = Color(hex: 0xC7D7DC)   // empty progress segment
    static let tealWash      = Color(hex: 0xE6EFF1)   // Guardian pill / label fill
    static let sageWash      = Color(hex: 0xEEF2E6)   // quiet image well on Guardian cards
    static let mossWash      = Color(hex: 0xF3F6EC)   // ticked piece tile
    static let honeyWash     = Color(hex: 0xFBF4E2)   // piece name tag after a transformation
}

// MARK: - Type

/// Child-facing text is a fixed size; Guardian text follows Dynamic Type (pass `scales: true`).
enum RokkoFont {
    /// Fredoka SemiBold: questions 34, buttons 30, labels 26, titles.
    static func fredoka(_ size: CGFloat, scales: Bool = false) -> Font {
        guard UIFont(name: "Fredoka-SemiBold", size: size) != nil else {
            return .system(size: size, weight: .semibold, design: .rounded)
        }
        return scales ? .custom("Fredoka-SemiBold", size: size)
                      : .custom("Fredoka-SemiBold", fixedSize: size)
    }

    /// Nunito (variable font): captions 26 Bold, Guardian body 20 Regular/SemiBold.
    static func nunito(_ size: CGFloat, _ weight: Font.Weight = .regular, scales: Bool = false) -> Font {
        guard UIFont.familyNames.contains("Nunito") else {
            return .system(size: size, weight: weight, design: .rounded)
        }
        return (scales ? Font.custom("Nunito", size: size) : Font.custom("Nunito", fixedSize: size)).weight(weight)
    }
}

// MARK: - Motion

enum RokkoMotion {
    /// Mirrors EngineConfig.json › motion.screenFadeMs (300). Read from RokkoContent once Phase 1 lands.
    static let screenFade: Double = 0.300
    /// Mirrors EngineConfig.json › motion.pressMs (120).
    static let press: Double = 0.120

    // Launch / ready castling (circles): king 0.7 s; rook starts 0.15 s later and takes 0.85 s.
    static let castleKing: Double = 0.70
    static let castleRookDelay: Double = 0.15
    static let castleRook: Double = 0.85

    /// One-finger long press on the Guardian button that opens the mood check (DECISIONS O6).
    static let moodHoldSeconds: Double = 2
    /// Mood sheet closes this long after a pick.
    static let moodSheetCloseDelay: Double = 0.7
}

// MARK: - Layout

enum RokkoLayout {
    /// Every screen is designed at 1194 × 834 pt and scaled to the device (13-inch: 1376 / 1194).
    static let canvas = CGSize(width: 1194, height: 834)
    static let margin: CGFloat = 40
    /// Primary button sits bottom-right: right 40, top 698, height 100.
    static let primaryButtonHeight: CGFloat = 100
    static let primaryButtonBottom: CGFloat = 834 - 698 - 100
}
