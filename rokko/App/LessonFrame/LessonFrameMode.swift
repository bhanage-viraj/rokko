//
//  LessonFrameMode.swift
//  The lesson frame components (top bar, caption, Next, Again, Guardian's turn, Guardian button,
//  mood sheet) report what the guardian does through `LessonFrameMode`.
//
//  • live:     events go to the lesson's sink (LessonCoordinator → RokkoEngine, BKT, SessionEvents,
//              lesson progress).
//  • practice: first-run setup. Events are dropped: no engine calls, no BKT updates, no
//              SessionEvents, no lesson progress saved. The component's own action still runs.
//

import SwiftUI

/// The guardian's answer in the mood check.
enum Mood: String, CaseIterable, Identifiable, Sendable {
    case ready, wobbly, needsBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ready: "Ready"
        case .wobbly: "Wobbly"
        case .needsBreak: "Needs a break"
        }
    }

    /// What it means, in a few words. Taught in first-run setup; not shown on the sheet.
    var detail: String {
        switch self {
        case .ready: "carry on as normal."
        case .wobbly: "slower, easier rounds."
        case .needsBreak: "take a short break."
        }
    }
}

/// Everything a lesson frame component can report.
enum LessonFrameEvent: Equatable, Sendable {
    case next
    case again
    case done
    case moodChosen(Mood)
    case menuOpened
}

/// Implemented by the LessonCoordinator; the only door from the frame to RokkoEngine and storage.
@MainActor
protocol LessonEventSink: AnyObject {
    func lessonFrame(didReport event: LessonFrameEvent)
}

enum LessonFrameMode {
    case live(any LessonEventSink)
    case practice

    var isPractice: Bool {
        if case .practice = self { return true }
        return false
    }

    /// Forwards to the lesson in live mode; does nothing in practice mode.
    @MainActor
    func report(_ event: LessonFrameEvent) {
        guard case .live(let sink) = self else { return }
        sink.lessonFrame(didReport: event)
    }
}

private struct LessonFrameModeKey: EnvironmentKey {
    static let defaultValue: LessonFrameMode = .practice
}

extension EnvironmentValues {
    /// Set `.live(coordinator)` on the lesson container; first-run setup keeps `.practice`.
    var lessonFrameMode: LessonFrameMode {
        get { self[LessonFrameModeKey.self] }
        set { self[LessonFrameModeKey.self] = newValue }
    }
}
