//
//  GuardianTurnPanel.swift
//  The text side of every Guardian's turn. TipsMode decides what shows:
//  full → the numbered steps; short → one line with "Show steps ›" (FR-14).
//

import SwiftUI

struct GuardianTurnContent: Equatable {
    /// "Show the real King"
    let title: String
    /// Numbered steps shown in full-tips mode.
    let steps: [String]
    /// One line shown in short-tips mode.
    let shortLine: String

    static let king = GuardianTurnContent(
        title: "Show the real King",
        steps: ["Hold up the King from your set.",
                "Ask: \u{201C}Which animal was this?\u{201D}",
                "Let your child feel the cross on top."],
        shortLine: "Hold up the King and ask which animal it was.")
}

struct GuardianTurnPanel: View {
    let content: GuardianTurnContent
    let tipsMode: TipsMode

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            GuardianLabel(fontSize: 18, fill: RokkoColor.tealWash)

            Text(content.title)
                .font(RokkoFont.fredoka(54))
                .foregroundStyle(RokkoColor.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 6) {
                if tipsMode == .full || expanded {
                    ForEach(Array(content.steps.enumerated()), id: \.offset) { i, step in
                        Text("\(i + 1)\u{2002}\(step)")
                    }
                } else {
                    Text(content.shortLine)
                    Button("Show steps \u{203A}") { expanded = true }
                        .font(RokkoFont.nunito(24, .heavy))
                        .foregroundStyle(RokkoColor.teal)
                        .padding(.top, 6)
                }
            }
            .font(RokkoFont.nunito(30, .bold))
            .lineSpacing(6)
            .foregroundStyle(RokkoColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(RokkoColor.card))
        }
        .frame(width: 560, alignment: .leading)
        .coachTarget(.guardianTurn)
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Guardian's turn · full tips", traits: .landscapeLeft) {
    DesignCanvas { GuardianTurnPanel(content: .king, tipsMode: .full) }
}
#Preview("Guardian's turn · short tips", traits: .landscapeLeft) {
    DesignCanvas { GuardianTurnPanel(content: .king, tipsMode: .short) }
}
#endif
