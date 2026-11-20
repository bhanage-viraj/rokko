//
//  LessonFrame.swift
//  The frame that never moves (CLAUDE.md product rules), drawn at 1194 × 834 pt:
//  top bar (pause · lesson path · Guardian button), bottom band (caption as plain text · Again · Next),
//  and the mood drop-down (out of the Guardian button) over a soft dim. Lesson content goes in the middle.
//  The same components run the real lesson (`.live`) and first-run practice (`.practice`).
//

import AVFoundation
import SwiftUI
import RokkoContent

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
    /// Film: the video fills the screen down to the caption row; the top bar floats over it.
    var video: AVPlayer? = nil
    /// The film clip has ended: its last picture dims and says Finished.
    var videoFinished = false
    /// Film subtitles: characters of the caption the voice has reached (nil = types out by itself).
    var captionShown: Int? = nil
    var next: LessonNextButton? = LessonNextButton()
    var showsAgain = false
    var moodSheetShown = false
    var selectedMood: Mood? = nil
    /// The engine suggests a check-in (FR-30): the Guardian button glows softly.
    var guardianGlows = false

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

    /// Real canvas size (≥ 1194 × 834). The top bar stays at the top, the bottom band at the bottom,
    /// and the 1194 × 834 stage sits centred between them, so no iPad shape leaves an empty strip.
    @Environment(\.canvasSize) private var canvas
    private var W: CGFloat { canvas.width }
    private var H: CGFloat { canvas.height }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            if let video {
                ClipVideoView(player: video, fills: true)
                    .frame(width: W, height: H - Self.bandHeight)
                    .clipped()
                    .accessibilityHidden(true)
                if videoFinished {
                    ZStack {
                        RokkoColor.ink.opacity(0.28)
                        FinishedTag()
                    }
                    .frame(width: W, height: H - Self.bandHeight)
                    .transition(.opacity)
                }
            }
            content()
                .frame(width: 1194, height: 834, alignment: .topLeading)
                .offset(x: (W - 1194) / 2, y: (H - 834) / 2)

            // Top bar
            RoundIconButton(systemName: "pause.fill", label: "Pause", action: onPause)
                .frame(width: 64, height: 64)
                .offset(x: 24, y: 24)
            LessonPath(done: pathDone, total: pathTotal)
                .opacity(pathDimmed ? 0.6 : 1)
                .frame(width: W, alignment: .center)
                .offset(y: 26)

            // Bottom band: one calm strip holding the caption (plain text, no pill), Again and Next.
            BottomBand()
                .frame(width: W, height: Self.bandHeight)
                .offset(y: H - Self.bandHeight)
            if let caption {
                CaptionBar(text: caption, shownByClip: captionShown)
                    .frame(width: W - Self.captionTrailing, height: 100, alignment: .leading)
                    .offset(x: 40, y: H - Self.buttonBottom - 100)
            }

            if showsAgain {
                AgainButton(action: onAgain)
                    // Same row as Next, just before it: right edge 16 pt left of Next, centred on it.
                    .frame(width: W - 40 - 200 - 16, height: H - Self.buttonBottom - 10, alignment: .bottomTrailing)
                    .transition(.opacity)
            }

            if let next {
                NextButton(config: next, action: onNext)
                    .frame(width: W - 40, height: H - Self.buttonBottom, alignment: .bottomTrailing)
            }

            RokkoColor.ink.opacity(moodSheetShown ? 0.3 : 0)
                .contentShape(Rectangle())
                .allowsHitTesting(moodSheetShown)
                .onTapGesture(perform: onMoodDismiss)
                .accessibilityHidden(true)
            if moodSheetShown {
                // Drops down from the Guardian button: same centre line, top just above it.
                MoodSheet(selected: selectedMood, onPick: onMoodPick)
                    .offset(x: guardianCenterX - MoodSheet.width / 2, y: Self.guardianTop - 10)
                    .transition(reduceMotion ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.4, anchor: .top)))
            }

            // Above the dim, so the drop-down reads as growing out of it.
            GuardianButton(glows: guardianGlows, onMoodHold: onMoodHold)
                .offset(x: guardianCenterX - 38, y: Self.guardianTop)
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .clipped()
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.12), value: moodSheetShown)
        .animation(.easeInOut(duration: 0.3), value: showsAgain)
    }

    /// Bottom band: from just under the stage (stage ends at design y 680) to the bottom edge.
    static var bandHeight: CGFloat { 834 - 682 }
    /// Next (100 pt) sits low in the band, 16 pt above the bottom edge. Caption shares its row.
    private static var buttonBottom: CGFloat { 16 }
    /// Caption ends 24 pt before Again (left margin 40 + Again 80 + gap 16 + Next 200 + right margin 40).
    private static var captionTrailing: CGFloat { 40 + 24 + 80 + 16 + 200 + 40 }

    /// Calm background: blur radius (pt) for the clearing, its saturation, and the paper wash on top.
    static var calmBlurRadius: CGFloat { 80 }
    static var calmSaturation: Double { 0.7 }
    static var calmPaperWash: Double { 0.45 }

    /// Guardian button: 76 pt, 24 pt in from the top-right corner.
    private static var guardianTop: CGFloat { 24 }
    private var guardianCenterX: CGFloat { W - 24 - 38 }

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
                    .frame(width: W, height: H)
                    // Calm: the same clearing, blurred as far as it goes (only soft colour fields
                    // remain, no shapes to look at) and desaturated −30% (DESIGN_SYSTEM).
                    .saturation(calm ? Self.calmSaturation : 1)
                    .blur(radius: calm ? Self.calmBlurRadius : 0, opaque: true)
                    .clipped()
                RokkoColor.paper.opacity(calm ? Self.calmPaperWash : 0.55)
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

/// Full-width strip at the bottom of every lesson screen: card colour, a cardEdge line on top and
/// a soft warm shadow upward, so it reads as one shelf for the caption and the buttons.
struct BottomBand: View {
    var body: some View {
        Rectangle()
            .fill(RokkoColor.card)
            .overlay(alignment: .top) { Rectangle().fill(RokkoColor.cardEdge).frame(height: 2) }
            .shadow(color: RokkoColor.ink.opacity(0.08), radius: 10, y: -4)
            .accessibilityHidden(true)
    }
}

/// "✓ Finished" on the dimmed last picture of a film clip, so the Guardian sees it has ended.
struct FinishedTag: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .accessibilityHidden(true)
            Text("Finished")
                .font(RokkoFont.fredoka(34))
        }
        .foregroundStyle(RokkoColor.ink)
        .padding(.horizontal, 30)
        .frame(minHeight: 72)
        .background(Capsule().fill(RokkoColor.card))
        .overlay(Capsule().strokeBorder(RokkoColor.cardEdge, lineWidth: 3))
        .accessibilityElement(children: .combine)
    }
}

/// Caption: the recorded line as plain text in the bottom band. No pill.
/// The caption types itself out: letters fade in one by one (EngineConfig › motion.captionCharMs).
/// Letters not shown yet keep their space, so the line never jumps.
struct CaptionBar: View {
    let text: String
    /// Film subtitles: characters shown, set by the clip time (words appear as they are said).
    /// nil = the line types itself out.
    var shownByClip: Int? = nil
    @State private var letters: [Character] = []
    @State private var shown = 0
    /// Reduce Motion: the whole line appears at once, no typing.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(styled)
            .font(RokkoFont.nunito(30, .bold))
            .foregroundStyle(RokkoColor.ink)
            .lineLimit(3)
            .minimumScaleFactor(0.7)
            .contentTransition(.interpolate)
            .animation(.easeOut(duration: Self.letterSeconds * 2), value: shown)
            .accessibilityLabel(text)
            .task(id: text) { await reveal() }
    }

    private var styled: AttributedString {
        let letters = shownByClip == nil ? letters : Array(text)
        let shown = shownByClip.map { reduceMotion ? letters.count : min($0, letters.count) } ?? shown
        var seen = AttributedString(String(letters.prefix(shown)))
        var rest = AttributedString(String(letters.dropFirst(shown)))
        seen.foregroundColor = RokkoColor.ink
        rest.foregroundColor = RokkoColor.ink.opacity(0)
        return seen + rest
    }

    private func reveal() async {
        letters = Array(text)
        if reduceMotion || shownByClip != nil { shown = letters.count; return }
        shown = 0
        for i in letters.indices {
            if i > 0 { try? await Task.sleep(for: .seconds(Self.letterSeconds)) }
            guard !Task.isCancelled else { return }
            shown = i + 1
        }
    }

    private static var letterSeconds: Double {
        if case .success(let library) = ContentLibrary.shared { return library.config.motion.captionCharMs / 1000 }
        return 0
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
        .accessibilityIdentifier(config.kind == .done ? "lesson.done" : "lesson.next")
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

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Frame · Standard", traits: .landscapeLeft) {
    DesignCanvas(background: RokkoColor.paper, fills: true) {
        LessonFrame(surface: .child(calm: false), pathDone: 2, pathTotal: 8,
                    caption: "Find the King.", showsAgain: true) { Color.clear }
    }
}
#Preview("Frame · Calm", traits: .landscapeLeft) {
    DesignCanvas(background: RokkoColor.paper, fills: true) {
        LessonFrame(surface: .child(calm: true), pathDone: 2, pathTotal: 8,
                    caption: "Find the King.", showsAgain: true) { Color.clear }
    }
}
#Preview("Frame · Done button", traits: .landscapeLeft) {
    DesignCanvas(background: RokkoColor.paper, fills: true) {
        LessonFrame(surface: .child(calm: true), pathDone: 7, pathTotal: 8,
                    caption: "Find the King.", next: LessonNextButton(kind: .done)) { Color.clear }
    }
}
#Preview("Frame · mood sheet open", traits: .landscapeLeft) {
    DesignCanvas(background: RokkoColor.paper, fills: true) {
        LessonFrame(surface: .child(calm: true), caption: "Find the King.",
                    moodSheetShown: true, selectedMood: .ready) { Color.clear }
    }
}
#Preview("Frame · Guardian's turn", traits: .landscapeLeft) {
    DesignCanvas(background: RokkoColor.mistBlue, fills: true) {
        LessonFrame(surface: .guardian, pathDone: 3, pathTotal: 8) {
            GuardianTurnPanel(content: .king, tipsMode: .full)
        }
    }
}
#Preview("Frame parts") {
    VStack(spacing: 24) {
        LessonPath(done: 3, total: 8)
        HStack(spacing: 16) {
            AgainButton {}
            NextButton(config: LessonNextButton(kind: .next)) {}
            NextButton(config: LessonNextButton(kind: .done)) {}
            NextButton(config: LessonNextButton(kind: .next, enabled: false)) {}
        }
        CaptionBar(text: "Find the white King.")
        HStack(spacing: 24) {
            StoryCircle(imageName: "char_lion_ivory", size: 200)
            StoryCircle(imageName: "piece_king_ivory", size: 200, gold: true)
            StoryTag(text: "King")
            StoryTag(text: "King", gold: true)
        }
    }
    .padding(40)
    .background(RokkoColor.paper)
}
#endif
