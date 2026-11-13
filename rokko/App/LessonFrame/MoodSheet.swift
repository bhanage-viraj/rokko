//
//  MoodSheet.swift
//  "How is your child?" — Ready / Wobbly / Needs a break. Only the guardian sets mood (ENGINE §6).
//  A drop-down that grows out of the Guardian button (top-right): one tall pill, the button at its
//  top, the three choices stacked below it as round buttons with a short label.
//

import SwiftUI

struct MoodSheet: View {
    var selected: Mood?
    let onPick: (Mood) -> Void

    @Environment(\.lessonFrameMode) private var mode

    /// Pill width; centred on the Guardian button (76 pt), kept inside the screen edge.
    static let width: CGFloat = 96
    /// Room left at the top of the pill for the Guardian button itself.
    static let buttonSlot: CGFloat = 76 + 18
    private let choiceSize: CGFloat = 76

    var body: some View {
        VStack(spacing: 18) {
            ForEach(Mood.allCases) { mood in
                Button {
                    mode.report(.moodChosen(mood))
                    onPick(mood)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: mood.symbol)
                            .font(.system(size: 30, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(RokkoColor.teal)
                            .frame(width: choiceSize, height: choiceSize)
                            .background(Circle().fill(RokkoColor.card))
                            .overlay(Circle().strokeBorder(selected == mood ? RokkoColor.teal : RokkoColor.cardEdge,
                                                           lineWidth: 3))
                            .background(Circle().stroke(RokkoColor.teal.opacity(selected == mood ? 0.2 : 0),
                                                        lineWidth: 10))
                        Text(mood.title)
                            .font(RokkoFont.nunito(17, .heavy))
                            .foregroundStyle(RokkoColor.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: Self.width - 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(mood.title)
                .accessibilityAddTraits(selected == mood ? .isSelected : [])
            }
        }
        .padding(.top, Self.buttonSlot)
        .padding(.bottom, 18)
        .frame(width: Self.width)
        .background(Capsule().fill(RokkoColor.mistBlue))
        .overlay(Capsule().strokeBorder(RokkoColor.mistEdge, lineWidth: 2))
        .shadow(color: RokkoColor.ink.opacity(0.25), radius: 18, y: 10)
        .coachTarget(.mood)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("How is your child?")
    }
}

extension Mood {
    /// Symbol on the round choice. Weather, never faces or colours with meaning.
    var symbol: String {
        switch self {
        case .ready: "sun.max.fill"
        case .wobbly: "cloud.sun.fill"
        case .needsBreak: "moon.zzz.fill"
        }
    }
}
