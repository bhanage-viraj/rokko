//
//  Store.swift
//  SwiftData storage. Everything stays on the iPad: no iCloud, no export.
//  Engine models (SkillState, ExerciseState, LessonProgress, SessionEvent): docs/ENGINE.md §8.
//

import Foundation
import SwiftData

// MARK: - Values

/// The six ivory characters.
enum Animal: String, CaseIterable, Codable, Identifiable, Sendable {
    case lion, lioness, elephant, horse, kangaroo, squirrel

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    /// Ivory character art, named as in docs/ASSETS.md.
    var imageName: String { "char_\(rawValue)_ivory" }
}

/// How much help each Guardian's turn shows.
enum TipsMode: String, Codable, Sendable {
    /// Every Guardian's turn shows its numbered steps.
    case full
    /// One line, with "Show steps ›" to expand.
    case short
}

// MARK: - Models

/// Guardian settings. ENGINE.md §8 calls this `Settings`; named `AppSettings` so it doesn't clash
/// with SwiftUI's `Settings` scene.
@Model
final class AppSettings {
    /// Calm (default) or Standard look and sound.
    var calm: Bool = true
    var sound: Bool = true
    /// Raw value of `TipsMode`.
    var tipsModeRaw: String = TipsMode.full.rawValue
    /// No longer used (the pieces checklist was removed, 23 Nov 2026); kept so saved stores still open.
    var piecesReady: Bool = false
    /// No longer used (see `piecesReady`).
    var piecesReminderShown: Bool = false
    /// First-run setup finished.
    var onboardingDone: Bool = false

    init() {}

    var tipsMode: TipsMode {
        get { TipsMode(rawValue: tipsModeRaw) ?? .full }
        set { tipsModeRaw = newValue.rawValue }
    }
}

/// P(known) for one skill (ENGINE §1).
@Model
final class SkillState {
    var skillRaw: String = ""
    var p: Double = 0.1
    var attempts: Int = 0
    var lastPractised: Date?

    init(skill: String, p: Double) {
        skillRaw = skill
        self.p = p
    }
}

/// One exercise (`LLL-M-TT-EE`): the last level played and how often each level was played
/// (the pool round at a level = plays mod rounds, ENGINE §7).
@Model
final class ExerciseState {
    var code: String = ""
    var lastLevel: Int?
    /// Plays at levels 1–6 (index 0 = level 1).
    var plays: [Int] = [0, 0, 0, 0, 0, 0]

    init(code: String) { self.code = code }

    func plays(at level: Int) -> Int { plays.indices.contains(level - 1) ? plays[level - 1] : 0 }

    func played(at level: Int) {
        lastLevel = level
        while plays.count < level { plays.append(0) }
        plays[level - 1] += 1
    }
}

/// Where the lesson is, so the next sitting resumes exactly there (FR-08).
@Model
final class LessonProgress {
    var lesson: Int = 1
    var stepId: String = ""
    /// `PlannerState` as JSON (the game block in progress).
    var plannerData: Data?
    var charcoalIntroSeen: Bool = false
    var completed: Bool = false
    /// Set by the Guardian; lasts until the next break ends (ENGINE §6).
    var wobbly: Bool = false
    var breaksTaken: Int = 0
    /// The child's counted response times (ms), oldest first, for the fast-tap median.
    var responseTimes: [Double] = []
    /// Per finished round: did a try not fit? (check-in signal)
    var roundsWithWrong: [Bool] = []
    /// Answer slot of the last choice round, so the answer never sits in the same slot twice.
    var lastAnswerSlot: Int?
    /// Furthest step reached (by Next). The Guardian can move back and forth up to here with the
    /// lesson path; nil = `stepId` (saved before this existed).
    var furthestStepId: String?

    init(lesson: Int, stepId: String) {
        self.lesson = lesson
        self.stepId = stepId
    }
}

/// One answer, kept on the iPad only, for the summary and the median. Trimmed to the newest
/// `storage.maxSessionEvents`.
@Model
final class SessionEvent {
    var time: Date = Date.now
    /// Full round code `LLL-M-TT-EE-V-III`.
    var code: String = ""
    var skillRaw: String = ""
    /// correct · incorrect · ignored
    var outcome: String = ""
    var hintLevel: Int = 0
    var responseMs: Double?
    var mood: String = ""

    init(code: String, skill: String, outcome: String, hintLevel: Int, responseMs: Double?, mood: String) {
        self.code = code
        skillRaw = skill
        self.outcome = outcome
        self.hintLevel = hintLevel
        self.responseMs = responseMs
        self.mood = mood
    }
}

// MARK: - Access

enum Store {
    static let models: [any PersistentModel.Type] = [AppSettings.self, SkillState.self, ExerciseState.self,
                                                    LessonProgress.self, SessionEvent.self]

    /// The single settings row, created on first use.
    @MainActor
    static func settings(in context: ModelContext) -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first { return existing }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }

    /// The lesson's progress row, created at its first step on first use.
    @MainActor
    static func progress(lesson: Int, firstStep: String, in context: ModelContext) -> LessonProgress {
        let all = (try? context.fetch(FetchDescriptor<LessonProgress>())) ?? []
        if let existing = all.first(where: { $0.lesson == lesson }) { return existing }
        let progress = LessonProgress(lesson: lesson, stepId: firstStep)
        context.insert(progress)
        return progress
    }

    @MainActor
    static func skills(in context: ModelContext) -> [SkillState] {
        (try? context.fetch(FetchDescriptor<SkillState>())) ?? []
    }

    @MainActor
    static func exercise(_ code: String, in context: ModelContext) -> ExerciseState {
        let all = (try? context.fetch(FetchDescriptor<ExerciseState>())) ?? []
        if let existing = all.first(where: { $0.code == code }) { return existing }
        let state = ExerciseState(code: code)
        context.insert(state)
        return state
    }

    /// Keeps only the newest `max` session events.
    @MainActor
    static func trimEvents(to max: Int, in context: ModelContext) {
        guard let count = try? context.fetchCount(FetchDescriptor<SessionEvent>()), count > max else { return }
        var oldest = FetchDescriptor<SessionEvent>(sortBy: [SortDescriptor(\.time)])
        oldest.fetchLimit = count - max
        for event in (try? context.fetch(oldest)) ?? [] { context.delete(event) }
    }
}
