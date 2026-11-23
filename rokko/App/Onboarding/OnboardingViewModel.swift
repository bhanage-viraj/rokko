//
//  OnboardingViewModel.swift
//  First-run setup (docs/ONBOARDING.md). Holds the answers, the step order, Back / Skip /
//  Continue rules, and what gets saved. No voice lines; the practice frames run in `.practice`.
//

import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {

    enum Step: Int, CaseIterable, Sendable {
        case welcome, look, tryGuardian, tryCheckIn, ready
    }

    enum Look: String, Sendable { case calm, standard }

    enum Piece: String, CaseIterable, Identifiable, Sendable {
        case king, rook, knight, queen, bishop, pawn   // story order
        var id: String { rawValue }
        var name: String { rawValue.capitalized }
        var imageName: String { "piece_\(rawValue)_ivory" }
    }

    /// What first-run setup writes to SwiftData.
    struct Result: Equatable, Sendable {
        var calm: Bool
    }

    // MARK: State

    private(set) var step: Step = .welcome
    var look: Look?
    /// tryGuardian: the guardian tapped Next on the Guardian's turn.
    var tryGuardianDone = false
    /// tryCheckIn: picked in the practice mood sheet. Not saved.
    var practiceMood: Mood?

    init(startAt step: Step = .welcome) { self.step = step }

    // MARK: Progress

    /// Steps counted in "Step N of 3" (welcome and ready sit outside).
    static let countedSteps: [Step] = [.look, .tryGuardian, .tryCheckIn]

    /// 1…3 for counted steps, nil for welcome and ready.
    var progressNumber: Int? { Self.countedSteps.firstIndex(of: step).map { $0 + 1 } }

    /// "2 of 3": short progress, for VoiceOver and compact spots.
    var progressShort: String {
        progressNumber.map { "\($0) of \(Self.countedSteps.count)" } ?? ""
    }

    var progressLabel: String {
        if let n = progressNumber { return "Step \(n) of \(Self.countedSteps.count)" }
        return step == .welcome ? "About 1 minute" : "Done"
    }

    var showsBack: Bool { step != .welcome && step != .ready }
    var showsSkip: Bool { step != .ready }
    /// Skip only works once the answer that changes the app is in: the look.
    var canSkip: Bool { showsSkip && look != nil }
    var showsTopBar: Bool { step != .ready }

    /// Steps that show the real app (below the setup bar), with a coach bubble.
    var isFullScreen: Bool { [.look, .tryGuardian, .tryCheckIn].contains(step) }

    // MARK: Continue

    var canContinue: Bool {
        switch step {
        case .welcome, .ready: true
        case .look: look != nil
        case .tryGuardian: tryGuardianDone
        case .tryCheckIn: practiceMood != nil
        }
    }

    var continueTitle: String {
        switch step {
        case .ready: "Start Lesson 1"
        default: "Next"
        }
    }

    // MARK: Navigation

    /// Continue. Does nothing until the step's action is done.
    func next() {
        guard canContinue, let following = Step(rawValue: step.rawValue + 1) else { return }
        step = following
    }

    /// Going back into a practice step resets it, so it can be done (and auto-advance) again.
    func back() {
        guard showsBack, let previous = Step(rawValue: step.rawValue - 1) else { return }
        switch previous {
        case .tryGuardian: tryGuardianDone = false
        case .tryCheckIn: practiceMood = nil
        default: break
        }
        step = previous
    }

    /// Only the check-in moves on by itself (it has no Next); every other step uses Next.
    var autoAdvances: Bool { step == .tryCheckIn }

    /// Pause before auto-advancing: long enough to see the result (and read the mood reply).
    var autoAdvanceDelay: Double { 2.6 }

    /// Jumps to ready, once the look is answered (the practice steps can be skipped).
    func skip() {
        guard canSkip else { return }
        step = .ready
    }

    // MARK: Answers → saved values

    /// Guardian's turns always show their full steps (the tips choice was removed, 23 Nov 2026).
    var tipsMode: TipsMode { .full }

    var result: Result {
        Result(calm: (look ?? .calm) == .calm)
    }

    /// Writes the result and marks setup done. Pieces aren't asked here: every lesson opens with
    /// "Get these pieces ready".
    func save(to settings: AppSettings) {
        let r = result
        settings.calm = r.calm
        settings.tipsMode = .full
        settings.onboardingDone = true
    }

    /// Practice frames never talk to the engine.
    let frameMode: LessonFrameMode = .practice

    // MARK: Ready summary chips

    var summaryChips: [String] {
        let r = result
        return [r.calm ? "Calm look" : "Standard look"]
    }
}
