//
//  LessonContainer.swift
//  The lesson on screen: one LessonFrame (top bar, caption, Next / Done, Again) around whatever the
//  LessonCoordinator is showing. Frame events go to the coordinator (`.live`).
//

import SwiftUI
import RokkoContent
import RokkoEngine

struct LessonContainer: View {
    @State private var coordinator: LessonCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(coordinator: LessonCoordinator) {
        _coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        let c = coordinator
        let path = c.pathParts
        DesignCanvas(background: c.isGuardianSurface ? RokkoColor.mistBlue : RokkoColor.paper, fills: true) {
            LessonFrame(surface: c.isGuardianSurface ? .guardian : .child(calm: c.calm),
                        pathDone: path.done,
                        pathTotal: path.total,
                        path: LessonPathModel(parts: c.pathSegments, current: path.done,
                                              furthestStep: c.furthestIndex,
                                              canGoBack: c.canGoBack, canGoForward: c.canGoForward,
                                              canOpen: c.canOpen, onBack: c.goBack,
                                              onForward: c.goForward, onOpen: c.open),
                        scenePan: CGFloat(c.stepIndex),
                        caption: c.caption,
                        video: c.fullScreenVideo,
                        videoFinished: c.filmFinished,
                        captionShown: c.captionShown,
                        next: c.screen == .sittingFull ? nil : LessonNextButton(kind: c.nextKind, enabled: c.nextEnabled),
                        showsAgain: c.showsAgain,
                        moodSheetShown: c.moodSheetShown,
                        selectedMood: c.mood,
                        guardianGlows: c.guardianGlows,
                        onPause: { c.paused = true },
                        onNext: c.next,
                        onAgain: c.again,
                        onMoodHold: { c.moodSheetShown = true },
                        onMoodPick: { _ in
                            Task {
                                try? await Task.sleep(for: .seconds(RokkoMotion.moodSheetCloseDelay))
                                c.moodSheetShown = false
                            }
                        },
                        onMoodDismiss: { c.moodSheetShown = false }) {
                // Each step slides in from the side it comes from (forward: from the right),
                // faster than the clearing behind it pans: depth. Calm / Reduce Motion: a fade.
                ZStack {
                    LessonStage(coordinator: c)
                        .animation(.easeInOut(duration: RokkoMotion.screenFade), value: c.screen)
                        .animation(.easeInOut(duration: RokkoMotion.screenFade), value: c.clipPlaying)
                        .id(c.stepIndex)
                        .transition(stepTransition(direction: c.lastMove, still: reduceMotion || c.calm))
                }
                .animation(.easeOut(duration: RokkoMotion.stepSlide), value: c.stepIndex)
            }
            .environment(\.lessonFrameMode, .live(c))
            .overlay { if c.paused { PausedOverlay(onResume: { c.paused = false }, onLeave: c.leaveLesson) } }
        }
        .environment(\.rokkoCalm, c.calm)
        .onAppear {
            c.reduceMotion = reduceMotion
            VoicePlayer.shared.muted = !c.settings.sound
            c.start()
        }
        .onChange(of: reduceMotion) { c.reduceMotion = reduceMotion }
        .onChange(of: scenePhase) { c.sceneActive(scenePhase == .active) }
    }
}

/// New step: slides in from `stepSlideShare` of the width on the side it comes from, fading in.
/// The step leaving only fades (its direction is not known when it was drawn).
private func stepTransition(direction: Int, still: Bool) -> AnyTransition {
    if still { return .opacity }
    let distance = RokkoLayout.canvas.width * RokkoMotion.stepSlideShare * CGFloat(direction)
    return .asymmetric(insertion: .offset(x: distance).combined(with: .opacity),
                       removal: .opacity)
}

/// The middle of the frame (1194 × 834 design points; the stage is y 112–680).
private struct LessonStage: View {
    let coordinator: LessonCoordinator

    var body: some View {
        let c = coordinator
        ZStack(alignment: .topLeading) {
            switch c.screen {
            case .step:
                StepStage(coordinator: c)
            case .getReady:
                GetReadyStage()
            case .blockIntro:
                CastRow(animals: c.blockAnimals, team: "ivory").offset(y: 200)
            case .round:
                if let round = c.round {
                    GameHost(scene: round.scene)
                        .frame(width: RokkoLayout.canvas.width, height: RokkoLayout.canvas.height)
                        .id(round.spec.id)
                }
            case .charcoalIntro:
                switch c.charcoalStage {
                case .animals: TwinRows(pieces: Piece.allCases, form: .character).id("animals")
                case .pieces: TwinRows(pieces: Piece.allCases, form: .piece).id("pieces")
                }
            case .sittingFull:
                SittingFullStage(onStop: c.stopForToday, onKeepGoing: c.keepGoing)
            case .breakPicker:
                BreakPickerStage(coordinator: c)
            case .breakRunning, .breakEnd:
                BreakRunningStage(coordinator: c)
            case .summary:
                SummaryStage(summary: c.summary)
            }
        }
        .frame(width: 1194, height: 834, alignment: .topLeading)
    }
}

// MARK: - Story steps

private struct StepStage: View {
    let coordinator: LessonCoordinator

    var body: some View {
        let c = coordinator
        let step = c.step
        switch step.kind {
        case .film:
            // Delivered film clips fill the screen (LessonFrame › video); the slot is only the placeholder.
            if c.fullScreenVideo == nil { ClipSlot(clip: step.clip, player: c.clipPlayer) }
        case .meet:
            if let animal = c.stepAnimal { MeetStage(animal: animal) }
        case .transform:
            if c.clipPlaying { ClipSlot(clip: step.clip, player: c.clipPlayer) }
            else if let piece = c.stepPiece { TransformedStage(piece: piece) }
        case .guardianShow:
            if let piece = step.piece {
                ZStack(alignment: .topLeading) {
                    StoryCircle(imageName: "piece_\(piece.rawValue)_ivory", size: 360).offset(x: 70, y: 160)
                    GuardianTurnPanel(content: .show(piece),
                                      tipsMode: .full)
                        .offset(x: 480, y: 128)
                }
            }
        case .guardianModule:
            ZStack(alignment: .topLeading) {
                VStack(spacing: 18) {
                    ForEach(step.pieces, id: \.self) { piece in
                        Image("piece_\(piece.rawValue)_ivory").resizable().scaledToFit()
                            .frame(width: 300, height: 150)
                    }
                }
                .frame(width: 400)
                .offset(x: 40, y: 140)
                .accessibilityHidden(true)
                GuardianTurnPanel(content: .module(step.pieces), tipsMode: .full)
                    .offset(x: 480, y: 128)
            }
        case .playTogether:
            PlayTogetherStage()
        case .complete:
            VStack(spacing: 8) {
                CastRow(animals: Animal.allCases, team: "ivory", height: 210)
                CastRow(animals: Animal.allCases, team: "charcoal", height: 170)
            }
            .offset(y: 150)
        case .gameBlock, .charcoalIntro, .break:
            EmptyView()
        }
    }
}

/// Where a video plays: the delivered clip, or a blank card until the video team delivers it (manifest.json).
struct ClipSlot: View {
    let clip: String?
    var player: ClipPlayer? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(RokkoColor.card)
            .overlay {
                if let player, player.hasClip {
                    ClipVideoView(player: player.player)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(RokkoColor.cardEdge, lineWidth: 3))
            .overlay(alignment: .bottomTrailing) {
                #if DEBUG
                if let clip, player?.hasClip != true {
                    Text(clip).font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(RokkoColor.inkSoft.opacity(0.6)).padding(16)
                }
                #endif
            }
            .frame(width: 880, height: 495)
            .frame(width: 1194)
            .offset(y: 148)
            .accessibilityHidden(true)
    }
}

/// Meet: the animal, large, on a soft ground shadow, with its name tag.
private struct MeetStage: View {
    let animal: Animal
    @MotionStill private var still
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottom) {
                GroundShadow().frame(width: 300, height: 40).offset(y: 14)
                Image(animal.imageName).resizable().scaledToFit()
                    .frame(width: 460, height: 360 * animal.relativeHeight, alignment: .bottom)
                    .scaleEffect(x: 1, y: breathe ? 1.015 : 1, anchor: .bottom)
            }
            .frame(height: 400, alignment: .bottom)
            StoryTag(text: "The \(animal.rawValue)")
        }
        .frame(width: 1194)
        .offset(y: 140)
        .accessibilityHidden(true)
        .onAppear {
            guard !still else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

/// After the transformation: the animal and the piece it became, the piece with its gold name tag.
private struct TransformedStage: View {
    let piece: Piece

    var body: some View {
        HStack(alignment: .bottom, spacing: 80) {
            VStack(spacing: 16) {
                StoryCircle(imageName: "char_\(piece.animal)_ivory", size: 300)
                StoryTag(text: "The \(piece.animal)")
            }
            VStack(spacing: 16) {
                StoryCircle(imageName: "piece_\(piece.rawValue)_ivory", size: 380, gold: true)
                StoryTag(text: piece.displayName, gold: true)
            }
        }
        .frame(width: 1194)
        .offset(y: 132)
    }
}

/// A row of characters standing on one line, at their relative heights (lion = `height`).
/// Each keeps its own width, so wide animals (the elephant) are not squeezed; the row shrinks to fit.
private struct CastRow: View {
    let animals: [Animal]
    let team: String
    var height: CGFloat = 300
    private let spacing: CGFloat = 20
    private let maxWidth: CGFloat = 1194 - 80

    var body: some View {
        let names = animals.map { "char_\($0.rawValue)_\(team)" }
        let aspects = names.map { name -> CGFloat in
            guard let size = UIImage(named: name)?.size, size.height > 0 else { return 1 }
            return size.width / size.height
        }
        let natural = zip(animals, aspects).map { height * $0.relativeHeight * $1 }
        let total = natural.reduce(0, +) + spacing * CGFloat(max(0, animals.count - 1))
        let scale = min(1, maxWidth / max(total, 1))
        let tallest = animals.map(\.relativeHeight).max() ?? 1
        HStack(alignment: .bottom, spacing: spacing * scale) {
            ForEach(Array(animals.enumerated()), id: \.offset) { i, animal in
                Image(names[i]).resizable().scaledToFit()
                    .frame(width: natural[i] * scale, height: height * animal.relativeHeight * scale)
            }
        }
        .frame(width: 1194, height: height * tallest * scale, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// Play together: the six animal + piece pairs, and two prompts for the Guardian (FR-31).
private struct PlayTogetherStage: View {
    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 18) {
                ForEach(Piece.allCases, id: \.self) { piece in
                    VStack(spacing: 6) {
                        Image("char_\(piece.animal)_ivory").resizable().scaledToFit().frame(width: 140, height: 120)
                        Image("piece_\(piece.rawValue)_ivory").resizable().scaledToFit().frame(width: 140, height: 120)
                    }
                    .padding(12)
                    .rokkoCard()
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                GuardianLabel()
                Text("1\u{2002}Put the six real pieces on the table. Say an animal; your child finds its piece.")
                Text("2\u{2002}Your child picks a piece and tells you its animal.")
            }
            .font(RokkoFont.nunito(22, .semibold, scales: true))
            .foregroundStyle(RokkoColor.ink)
            .padding(.horizontal, 28).padding(.vertical, 18)
            .frame(width: 960, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(RokkoColor.card.opacity(0.95)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(RokkoColor.mistEdge, lineWidth: 3))
        }
        .frame(width: 1194)
        .offset(y: 130)
    }
}

/// Black team intro: each white figure on top, and its black twin appearing under it, one by one,
/// so the child sees "same animal (same piece), other colour". Reduce Motion / Calm: a plain fade.
private struct TwinRows: View {
    let pieces: [Piece]
    let form: ItemForm
    @State private var shown = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 28) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { i, piece in
                VStack(spacing: 18) {
                    FigureImage(piece: piece, form: form, black: false)
                    FigureImage(piece: piece, form: form, black: true)
                        .opacity(i < shown ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5), value: shown)
                }
            }
        }
        .frame(width: 1194)
        .offset(y: 150)
        .accessibilityHidden(true)
        .task {
            // The twins arrive one by one, 0.6 s apart.
            for i in 1...pieces.count {
                try? await Task.sleep(for: .seconds(i == 1 ? 0.8 : 0.6))
                shown = i
            }
        }
    }
}

/// One figure for the intro rows: a character or a piece, white or black.
private struct FigureImage: View {
    let piece: Piece
    let form: ItemForm
    let black: Bool

    var body: some View {
        if form == .character {
            Image("char_\(piece.animal)_\(black ? "charcoal" : "ivory")").resizable().scaledToFit()
                .frame(width: 150, height: 200)
        } else {
            PieceImage(piece: piece, black: black).frame(width: 110, height: 200)
        }
    }
}

/// A piece, white or black. Until the black piece art arrives, the white art is tinted slate (as in the games).
struct PieceImage: View {
    let piece: Piece
    let black: Bool

    var body: some View {
        let charcoal = "piece_\(piece.rawValue)_charcoal"
        if black, UIImage(named: charcoal) != nil {
            Image(charcoal).resizable().scaledToFit()
        } else if black {
            Image("piece_\(piece.rawValue)_ivory").resizable().scaledToFit()
                .colorMultiply(RokkoColor.charcoalTint).brightness(0.12)
        } else {
            Image("piece_\(piece.rawValue)_ivory").resizable().scaledToFit()
        }
    }
}

/// Guardian's turn after the black team intro: put one of each black piece out next to the white ones.
// MARK: - Guardian screens

/// Start of every sitting: the pieces the lesson needs, white and black, side by side.
/// Nothing to tap here; Next carries on into the lesson.
private struct GetReadyStage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            GuardianHeader(label: "Guardian", title: "Get these pieces ready",
                           detail: "One of each, white and black, on the table next to the iPad.")
            VStack(spacing: 18) {
                row(black: false)
                row(black: true)
            }
        }
        .frame(width: 1194 - 128, alignment: .leading)
        .offset(x: 64, y: 124)
    }

    private func row(black: Bool) -> some View {
        HStack(spacing: 18) {
            ForEach(Piece.allCases, id: \.self) { piece in
                VStack(spacing: 6) {
                    PieceImage(piece: piece, black: black)
                        .frame(height: 112)
                        .accessibilityHidden(true)
                    Text(piece.displayName)
                        .font(RokkoFont.fredoka(19, scales: true))
                        .foregroundStyle(RokkoColor.bark)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .rokkoCard(radius: 24, edge: RokkoColor.mistEdgeSoft, edgeWidth: 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(black ? "Black" : "White") \(piece.displayName)")
            }
        }
    }
}

private struct SittingFullStage: View {
    let onStop: () -> Void
    let onKeepGoing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            GuardianHeader(label: "Guardian", title: "Stop here for today?",
                           detail: "Your child has played many rounds. Next time starts in this game, where you stopped.")
            HStack(spacing: 20) {
                PrimaryButton(title: "Stop here for today", action: onStop)
                SecondaryButton(title: "Keep going", height: 100, fontSize: 26, action: onKeepGoing).frame(width: 300)
            }
        }
        .frame(width: 900, alignment: .leading)
        .offset(x: 64, y: 160)
    }
}

/// End of the lesson, for the Guardian: one card per piece (picture, how well it is known in words,
/// a 3-step meter and the real answers behind it), then colours / teams, days and breaks.
/// Drawn in the stage (y 112–680 of the 1194 × 834 design).
private struct SummaryStage: View {
    let summary: LessonSummary

    private let columns = Array(repeating: GridItem(.fixed(344), spacing: 20), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    GuardianLabel(text: "Guardian")
                    GuardianTitle(text: "Lesson 1 is done")
                }
                Spacer()
                Text(intro)
                    .font(RokkoFont.nunito(18, .semibold, scales: true))
                    .foregroundStyle(RokkoColor.inkSoft)
                    .multilineTextAlignment(.trailing)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(summary.pieces) { PieceSummaryCard(row: $0) }
            }
            HStack(spacing: 14) {
                ForEach(summary.extras) { extra in
                    SummaryFact(systemImage: extra.title == "White and black" ? "circle.lefthalf.filled" : "person.3.fill",
                                title: extra.title, value: extra.level.words)
                }
                SummaryFact(systemImage: "calendar", title: "Days played", value: "\(summary.days)")
                SummaryFact(systemImage: "cup.and.saucer.fill", title: "Breaks", value: "\(summary.breaks)")
            }
        }
        .frame(width: 1072, alignment: .leading)
        .offset(x: 61, y: 128)
    }

    private var intro: String {
        summary.answers == 0 ? "No games played yet."
                             : "From \(summary.answers) answers, kept on this iPad."
    }
}

private struct PieceSummaryCard: View {
    let row: LessonSummary.PieceRow

    var body: some View {
        HStack(spacing: 16) {
            Image("piece_\(row.piece.rawValue)_ivory")
                .resizable().scaledToFit()
                .frame(width: 64, height: 104)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(row.piece.displayName)
                    .font(RokkoFont.fredoka(24, scales: true))
                    .foregroundStyle(RokkoColor.ink)
                HStack(spacing: 8) {
                    LevelMeter(steps: row.level.steps)
                    Text(row.level.words)
                        .font(RokkoFont.nunito(17, .bold, scales: true))
                        .foregroundStyle(RokkoColor.ink)
                }
                Text(detail)
                    .font(RokkoFont.nunito(15, .semibold, scales: true))
                    .foregroundStyle(RokkoColor.inkSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(width: 344, height: 136, alignment: .leading)
        .rokkoCard(radius: 22, edge: RokkoColor.mistEdgeSoft, edgeWidth: 2)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        guard row.tries > 0 else { return "Not played yet" }
        var parts = ["\(row.tries) \(row.tries == 1 ? "try" : "tries")", "\(row.firstGo) first go"]
        if row.withHelp > 0 { parts.append("\(row.withHelp) with a hint") }
        return parts.joined(separator: " · ")
    }
}

/// Three short bars: still learning · getting there · knows it well.
private struct LevelMeter: View {
    let steps: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= steps ? RokkoColor.moss : RokkoColor.mistTrack)
                    .frame(width: 18, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SummaryFact: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(RokkoColor.teal)
                .frame(width: 40, height: 40)
                .background(Circle().fill(RokkoColor.tealWash))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RokkoFont.nunito(14, .bold, scales: true))
                    .foregroundStyle(RokkoColor.inkSoft)
                Text(value)
                    .font(RokkoFont.nunito(18, .bold, scales: true))
                    .foregroundStyle(RokkoColor.ink)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
        .rokkoCard(radius: 18, edge: RokkoColor.mistEdgeSoft, edgeWidth: 2)
        .accessibilityElement(children: .combine)
    }
}

/// Pause: everything stops; Resume (and Leave lesson, which keeps the exact place).
private struct PausedOverlay: View {
    let onResume: () -> Void
    let onLeave: () -> Void

    var body: some View {
        ZStack {
            // Everything behind (top bar, path, film still, bottom band) goes soft and quiet alike.
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            RokkoColor.ink.opacity(0.18).ignoresSafeArea()
            VStack(spacing: 28) {
                // One big round play button: tap to carry on.
                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 54, weight: .heavy))
                        .foregroundStyle(RokkoColor.card)
                        .offset(x: 5)   // optical centre of the triangle
                        .frame(width: 140, height: 140)
                        .background(Circle().fill(RokkoColor.leaf)
                            .shadow(color: RokkoColor.ink.opacity(0.22), radius: 10, y: 5))
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Resume")
                Button("Leave lesson", action: onLeave)
                    .font(RokkoFont.nunito(20, .bold, scales: true))
                    .foregroundStyle(RokkoColor.teal)
                    .frame(minWidth: 200, minHeight: 56)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 40)
            .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(RokkoColor.card)
                .shadow(color: RokkoColor.ink.opacity(0.18), radius: 20, y: 8))
        }
    }
}

// MARK: - Breaks

private struct BreakPickerStage: View {
    @Bindable var coordinator: LessonCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            GuardianHeader(label: "Guardian", title: "Time for a break",
                           detail: "Pick what to do and for how long.")
            HStack(spacing: 18) {
                ForEach(BreakActivity.allCases) { activity in
                    let on = coordinator.breakActivity == activity
                    Button { coordinator.breakActivity = activity } label: {
                        VStack(spacing: 12) {
                            Image(activity.animal.imageName).resizable().scaledToFit().frame(height: 130)
                                .accessibilityHidden(true)
                            Text(activity.title)
                                .font(RokkoFont.fredoka(20, scales: true))
                                .foregroundStyle(RokkoColor.ink)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .frame(width: 240, height: 230)
                        .rokkoCard(edge: on ? RokkoColor.teal : RokkoColor.mistEdge, edgeWidth: on ? 4 : 3)
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            HStack(spacing: 14) {
                ForEach(coordinator.config.breaks.minutes, id: \.self) { minutes in
                    let on = coordinator.breakMinutes == minutes
                    Button { coordinator.breakMinutes = minutes } label: {
                        Text(minutes == 1 ? "1 minute" : "\(minutes) minutes")
                            .font(RokkoFont.nunito(20, .bold, scales: true))
                            .foregroundStyle(on ? RokkoColor.card : RokkoColor.teal)
                            .padding(.horizontal, 22)
                            .frame(minHeight: 56)
                            .background(Capsule().fill(on ? RokkoColor.teal : RokkoColor.card))
                            .overlay(Capsule().strokeBorder(RokkoColor.teal, lineWidth: 2))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .offset(x: 64, y: 120)
    }
}

/// The break: the character models the activity inside a ring of leaves that go one by one (leaf timer).
private struct BreakRunningStage: View {
    let coordinator: LessonCoordinator
    private let leaves = 12

    var body: some View {
        let c = coordinator
        ZStack(alignment: .topLeading) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = c.breakFractionLeft(at: context.date)
                ZStack {
                    ForEach(0..<leaves, id: \.self) { i in
                        Ellipse()
                            .fill(RokkoColor.moss)
                            .frame(width: 22, height: 44)
                            .offset(y: -250)
                            .rotationEffect(.degrees(Double(i) / Double(leaves) * 360))
                            .opacity(Double(i) < (left * Double(leaves)).rounded(.up) ? 1 : 0.15)
                            .animation(.easeInOut(duration: 0.8), value: left)
                    }
                    Image(c.breakActivity.animal.imageName).resizable().scaledToFit()
                        .frame(width: 320, height: 340 * max(0.6, c.breakActivity.animal.relativeHeight))
                }
                .frame(width: 1194, height: 560)
                .offset(y: 116)
                .accessibilityHidden(true)
            }
            if c.screen == .breakRunning {
                BreakTimeControls(coordinator: c)
                    .offset(x: 40, y: 590)
            }
        }
    }
}

/// Guardian's corner of the break: the time left (m:ss) and the add-time button.
/// Adding time pops a "+1 min" that floats up and fades (under 1 s); Calm / Reduce Motion: a plain fade.
private struct BreakTimeControls: View {
    let coordinator: LessonCoordinator
    @MotionStill private var still
    @State private var popID = 0
    @State private var popUp = false

    var body: some View {
        let c = coordinator
        HStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let s = c.breakSecondsLeft(at: context.date)
                HStack(spacing: 10) {
                    Image(systemName: "clock").accessibilityHidden(true)
                    Text(String(format: "%d:%02d", s / 60, s % 60))
                        .monospacedDigit()
                        .contentTransition(still ? .opacity : .numericText(countsDown: true))
                        .animation(still ? .easeInOut(duration: 0.3) : .snappy, value: s)
                }
                .font(RokkoFont.fredoka(28))
                .foregroundStyle(RokkoColor.ink)
                .padding(.horizontal, 22)
                .frame(minHeight: 64)
                .background(Capsule().fill(RokkoColor.card))
                .overlay(Capsule().strokeBorder(RokkoColor.mistEdge, lineWidth: 2))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Time left: \(s / 60) minutes \(s % 60) seconds")
            }

            SecondaryButton(title: "+\(c.config.breaks.addMinutes) min", systemImage: "timer",
                            height: 64, action: c.addBreakMinute)
                .frame(width: 180)
                .accessibilityLabel("Add \(c.config.breaks.addMinutes) minute")
                .overlay(alignment: .top) {
                    Text("+\(c.config.breaks.addMinutes) min")
                        .font(RokkoFont.fredoka(26))
                        .foregroundStyle(RokkoColor.leaf)
                        .id(popID)
                        .opacity(popUp ? 0 : (popID == 0 ? 0 : 1))
                        .offset(y: popUp && !still ? -70 : -20)
                        .scaleEffect(popUp && !still ? 1.15 : 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        }
        .onChange(of: c.breakTimeAdded) {
            popUp = false
            popID += 1
            withAnimation(.easeOut(duration: 0.8)) { popUp = true }
        }
    }
}

// MARK: - Content helpers

extension GuardianTurnContent {
    /// Show the real piece (FR-14).
    static func show(_ piece: Piece) -> GuardianTurnContent {
        let feel: String = switch piece {
        case .king: "Let your child feel the cross on top."
        case .queen: "Let your child feel the small crown on top."
        case .rook: "Let your child feel the notches of the tower."
        case .bishop: "Let your child feel the pointed top."
        case .knight: "Let your child feel the horse\u{2019}s head."
        case .pawn: "Let your child feel the round head."
        }
        return GuardianTurnContent(
            title: "Show the real \(piece.displayName)",
            steps: ["Hold up the \(piece.displayName) from your set.",
                    "Ask: \u{201C}Which animal was this?\u{201D}",
                    feel],
            shortLine: "Hold up the \(piece.displayName) and ask which animal it was.")
    }

    /// The module's Guardian's turn (FR-15, DECISIONS O8).
    static func module(_ pieces: [Piece]) -> GuardianTurnContent {
        let names = pieces.map { "the \($0.displayName)" }
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + names.last! : names.joined()
        return GuardianTurnContent(
            title: "Show the \(pieces.count == 3 ? "three" : "\(pieces.count)") pieces",
            steps: ["Put \(list) in front of your child.",
                    "Say a piece name. Your child points to it.",
                    "Ask: \u{201C}Which animal is this?\u{201D}"],
            shortLine: "Name each piece; your child points to it and names its animal.")
    }
}

extension Animal {
    /// Heights relative to the lion (DESIGN_SYSTEM › Characters, DECISIONS O4).
    var relativeHeight: CGFloat {
        switch self {
        case .elephant: 1.35
        case .lion: 1.00
        case .horse: 0.95
        case .lioness: 0.92
        case .kangaroo: 0.70
        case .squirrel: 0.40
        }
    }
}
