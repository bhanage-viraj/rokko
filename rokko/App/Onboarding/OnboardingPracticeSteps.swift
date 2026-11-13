//
//  OnboardingPracticeSteps.swift
//  look · tryGuardian · tryCheckIn. Each shows the real LessonFrame (below the setup bar),
//  in practice mode (no engine, no BKT, no SessionEvents, no lesson progress), with a coach
//  bubble giving the one-line instruction.
//

import SwiftUI

// MARK: - look: the whole screen switches between Calm and Standard

struct LookStep: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        LessonFrame(surface: .child(calm: model.look != .standard),
                    next: LessonNextButton(kind: .next, enabled: model.look != nil),
                    onNext: model.next) {
            StoryCircle(imageName: Animal.lion.imageName).offset(x: 240, y: 150)
        }
        .coachOverlay(target: nil, fallback: .trailing) {
            VStack(alignment: .leading, spacing: 14) {
                CoachMessage(text: "How do busy screens feel?")
                CoachChoice(title: "Calm", selected: model.look == .calm) { model.look = .calm }
                CoachChoice(title: "Standard", selected: model.look == .standard) { model.look = .standard }
            }
        }
    }
}

// MARK: - tryGuardian: what blue screens are for

struct TryGuardianStep: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        LessonFrame(surface: .guardian,
                    pathDimmed: true,
                    next: LessonNextButton(kind: .next),
                    onNext: {
                        // Next behaves like Next everywhere: it moves on straight away.
                        model.tryGuardianDone = true
                        model.next()
                    }) {
            ZStack(alignment: .topLeading) {
                StoryCircle(imageName: "piece_king_ivory", size: 360).offset(x: 70, y: 140)
                GuardianTurnPanel(content: .king, tipsMode: model.tipsMode).offset(x: 480, y: 108)
            }
        }
        // The point of this screen: blue = the guardian's turn with the real piece. Next is not taught.
        .coachOverlay(target: .guardianTurn, isPresented: !model.tryGuardianDone) {
            CoachMessage(text: "Blue screens are **your turn**. Pick up the real King and show it to your child.")
        }
    }
}

// MARK: - tryCheckIn: long press → mood drop-down

struct TryCheckInStep: View {
    @Bindable var model: OnboardingViewModel
    let calm: Bool

    /// DEBUG: `-RokkoMoodSheet YES` opens the sheet on launch (for screenshots).
    @State private var sheetShown = UserDefaults.standard.bool(forKey: "RokkoMoodSheet")

    var body: some View {
        LessonFrame(surface: .child(calm: calm),
                    next: nil,
                    moodSheetShown: sheetShown,
                    selectedMood: model.practiceMood,
                    onMoodHold: { sheetShown = true },
                    onMoodPick: pick,
                    onMoodDismiss: { sheetShown = false }) {
            ZStack(alignment: .topLeading) {
                StoryCircle(imageName: Animal.lion.imageName, size: 250)
                    .frame(width: 1194)
                    .offset(y: 120)
                HStack(spacing: 28) {
                    ForEach(["piece_rook_ivory", "piece_pawn_ivory", "piece_king_ivory"], id: \.self) { name in
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 190)
                            .frame(width: 220, height: 240)
                            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(RokkoColor.card))
                            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(RokkoColor.cardEdge, lineWidth: 3))
                    }
                }
                .frame(width: 1194)
                .offset(y: 420)
                .accessibilityHidden(true)
            }
        }
        .coachOverlay(target: choosing ? .mood : .guardian,
                      highlight: model.practiceMood == nil,
                      isPresented: !sheetShown || model.practiceMood == nil,
                      blursBackground: true,
                      bubbleWidth: choosing ? 440 : 360,
                      placement: choosing ? .leading : .vertical) {
            VStack(alignment: .leading, spacing: 10) {
                if choosing {
                    Text("How is your child?")
                        .font(RokkoFont.fredoka(26, scales: true))
                        .foregroundStyle(RokkoColor.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                CoachMessage(text: coachText)
            }
        }
    }

    /// The drop-down is open and nothing is picked yet: the bubble sits left of it, pointing in.
    private var choosing: Bool { sheetShown && model.practiceMood == nil }

    private var coachText: String {
        if let mood = model.practiceMood { return Self.reply(mood) }
        if sheetShown {
            return Mood.allCases.map { "**\($0.title)**: \($0.detail)" }.joined(separator: "\n")
        }
        return "**Press and hold** here for 2 seconds."
    }

    private func pick(_ mood: Mood) {
        model.practiceMood = mood
        Task {
            try? await Task.sleep(for: .seconds(RokkoMotion.moodSheetCloseDelay))
            sheetShown = false
        }
    }

    /// After a pick: what Rokko would now do.
    static func reply(_ mood: Mood) -> String {
        switch mood {
        case .ready: "**Ready**: the lesson carries on as normal."
        case .wobbly: "**Wobbly**: Rokko slows down and makes the next rounds easier."
        case .needsBreak: "**Needs a break**: a short break starts, and you pick the activity."
        }
    }
}
