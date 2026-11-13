//
//  LessonFrame.swift
//  The frame that never moves (CLAUDE.md product rules), drawn at 1194 × 834 pt:
//  top bar (pause · lesson path · Guardian button), caption bar, Again directly above Next,
//  and the mood drop-down (out of the Guardian button) over a soft dim. Lesson content goes in the middle.
//  The same components run the real lesson (`.live`) and first-run practice (`.practice`).
//

import SwiftUI

enum LessonSurface: Equatable {
    /// Child screen. Calm = flat paper; Standard = painted clearing.
    case child(calm: Bool)
    /// Guardian's turn (blue).
    case guardian
}

struct LessonNextButton: Equatable {
    enum Kind: Equatable { case next, done }
    var kind: Kind = .next
    var enabled = true
}

struct LessonFrame<Content: View>: View {
    var surface: LessonSurface = .child(calm: true)
    /// Lesson path: steps finished, and the current step (0-based).
    var pathDone = 1
    var pathTotal = 8
    var pathDimmed = false
    var caption: String? = nil
    var next: LessonNextButton? = LessonNextButton()
    var showsAgain = false
    var moodSheetShown = false
    var selectedMood: Mood? = nil

    var onPause: () -> Void = {}
    var onNext: () -> Void = {}
    var onAgain: () -> Void = {}
    var onMoodHold: () -> Void = {}
    var onMoodPick: (Mood) -> Void = { _ in }
    /// Tap outside the open mood drop-down.
    var onMoodDismiss: () -> Void = {}

    @ViewBuilder var content: () -> Content

    @Environment(\.lessonFrameMode) private var mode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            content()

            // Top bar
            RoundIconButton(systemName: "pause.fill", label: "Pause", action: onPause)
                .frame(width: 64, height: 64)
                .offset(x: 24, y: 24)
            LessonPath(done: pathDone, total: pathTotal)
                .opacity(pathDimmed ? 0.6 : 1)
                .frame(width: 1194, alignment: .center)
                .offset(y: 26)

            if let caption {
                CaptionBar(text: caption).offset(x: 40, y: 698)
            }

            if showsAgain {
                AgainButton(action: onAgain)
                    // Same row as Next, just before it: right edge 16 pt left of Next, centred on it.
                    .frame(width: 1194 - 40 - 200 - 16, height: 834 - 34 - 10, alignment: .bottomTrailing)
                    .transition(.opacity)
            }

            if let next {
                NextButton(config: next, action: onNext)
                    .frame(width: 1194 - 40, height: 834 - 34, alignment: .bottomTrailing)
            }

            RokkoColor.ink.opacity(moodSheetShown ? 0.3 : 0)
                .contentShape(Rectangle())
                .allowsHitTesting(moodSheetShown)
                .onTapGesture(perform: onMoodDismiss)
                .accessibilityHidden(true)
            if moodSheetShown {
                // Drops down from the Guardian button: same centre line, top just above it.
                MoodSheet(selected: selectedMood, onPick: onMoodPick)
                    .offset(x: Self.guardianCenterX - MoodSheet.width / 2, y: Self.guardianTop - 10)
                    .transition(reduceMotion ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.4, anchor: .top)))
            }

            // Above the dim, so the drop-down reads as growing out of it.
            GuardianButton(onMoodHold: onMoodHold)
                .offset(x: Self.guardianCenterX - 38, y: Self.guardianTop)
        }
        .frame(width: 1194, height: 834, alignment: .topLeading)
        .clipped()
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.12), value: moodSheetShown)
        .animation(.easeInOut(duration: 0.3), value: showsAgain)
    }

    /// Guardian button: 76 pt, 24 pt in from the top-right corner.
    private static var guardianTop: CGFloat { 24 }
    private static var guardianCenterX: CGFloat { 1194 - 24 - 38 }

    @ViewBuilder private var background: some View {
        switch surface {
        case .guardian:
            RokkoColor.mistBlue
        case .child(let calm):
            ZStack {
                RokkoColor.paper
                Image("bg_clearing")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 1194, height: 834)
                    .clipped()
                    .opacity(calm ? 0 : 1)
                RokkoColor.paper.opacity(0.55)
            }
            .animation(.easeInOut(duration: 0.4), value: calm)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Pieces of the frame

struct RoundIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(RokkoColor.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Circle().fill(RokkoColor.card).shadow(color: RokkoColor.ink.opacity(0.14), radius: 6, y: 4))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

/// Lesson path pill: finished steps sage, current step outlined, the rest dashed. No numbers.
struct LessonPath: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<total, id: \.self) { i in
                Group {
                    if i < done {
                        Circle().fill(RokkoColor.sageDone)
                    } else if i == done {
                        Circle().strokeBorder(RokkoColor.ink, lineWidth: 3)
                    } else {
                        Circle().strokeBorder(RokkoColor.cardEdge, style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
                    }
                }
                .frame(width: 34, height: 34)
            }
        }
        .frame(width: 560, height: 60)
        .background(Capsule().fill(RokkoColor.card.opacity(0.9)))
        .accessibilityHidden(true)
    }
}

struct CaptionBar: View {
    let text: String
    var body: some View {
        Text(text)
            .font(RokkoFont.nunito(30, .bold))
            .foregroundStyle(RokkoColor.ink)
            .lineLimit(2)
            .padding(.horizontal, 34)
            .frame(maxWidth: 860, minHeight: 96, maxHeight: 96, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
            .background(Capsule().fill(RokkoColor.card).shadow(color: RokkoColor.ink.opacity(0.10), radius: 8, y: 6))
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: text)
    }
}

struct NextButton: View {
    let config: LessonNextButton
    let action: () -> Void

    @Environment(\.lessonFrameMode) private var mode

    var body: some View {
        Button {
            mode.report(config.kind == .done ? .done : .next)
            action()
        } label: {
            HStack(spacing: 12) {
                Text(config.kind == .done ? "Done" : "Next")
                if config.kind == .next {
                    Image(systemName: "arrow.right").font(.system(size: 30, weight: .heavy))
                }
            }
            .font(RokkoFont.fredoka(38))
            .foregroundStyle(RokkoColor.card)
            .frame(width: 200, height: 100)
            .background(Capsule().fill(RokkoColor.leaf).shadow(color: RokkoColor.leaf.opacity(0.22), radius: 7, y: 6))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!config.enabled)
        .opacity(config.enabled ? 1 : 0.35)
        .animation(.easeOut(duration: 0.25), value: config.enabled)
        .coachTarget(.next)
    }
}

struct AgainButton: View {
    let action: () -> Void

    @Environment(\.lessonFrameMode) private var mode

    var body: some View {
        Button {
            mode.report(.again)
            action()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(RokkoColor.leaf)
                .frame(width: 80, height: 80)
                .background(Circle().fill(RokkoColor.card))
                .overlay(Circle().strokeBorder(RokkoColor.leaf, lineWidth: 3))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Again")
        .coachTarget(.again)
    }
}

/// Character or piece shown in a card circle (meet / transform placeholder until SpriteKit scenes).
struct StoryCircle: View {
    let imageName: String
    var size: CGFloat = 420
    var gold = false

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.76, height: size * 0.76)
            .frame(width: size, height: size)
            .background(Circle().fill(RokkoColor.card))
            .overlay(Circle().strokeBorder(gold ? RokkoColor.honey : RokkoColor.cardEdge, lineWidth: 4))
            .background(Circle().stroke(RokkoColor.honey.opacity(gold ? 0.18 : 0), lineWidth: 28))
            .shadow(color: RokkoColor.ink.opacity(0.12), radius: 12, y: 8)
            .accessibilityHidden(true)
    }
}

/// Name tag under a story circle ("The lion", "King").
struct StoryTag: View {
    let text: String
    var gold = false

    var body: some View {
        Text(text)
            .font(RokkoFont.fredoka(32))
            .foregroundStyle(RokkoColor.bark)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(Capsule().fill(gold ? RokkoColor.honeyWash : RokkoColor.card))
            .overlay(Capsule().strokeBorder(gold ? RokkoColor.honey : RokkoColor.cardEdge, lineWidth: 3))
            .fixedSize()
    }
}
