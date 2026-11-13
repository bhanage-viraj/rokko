//
//  Store.swift
//  SwiftData storage. Everything stays on the iPad: no iCloud, no export.
//  Engine models (SkillState, ExerciseState, LessonProgress, SessionEvent) arrive with the
//  lesson; see docs/ENGINE.md §8.
//

import Foundation
import SwiftData

// MARK: - Values

/// The six ivory characters.
enum Animal: String, CaseIterable, Codable, Identifiable, Sendable {
    case lion, lioness, elephant, horse, fox, squirrel

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
    /// The guardian said all six white pieces are out (first-run setup, pieces step).
    var piecesReady: Bool = false
    /// The pieces checklist has been shown once inside the lesson (for families who chose "later").
    var piecesReminderShown: Bool = false
    /// First-run setup finished.
    var onboardingDone: Bool = false

    init() {}

    var tipsMode: TipsMode {
        get { TipsMode(rawValue: tipsModeRaw) ?? .full }
        set { tipsModeRaw = newValue.rawValue }
    }

    /// True when the lesson should show the pieces checklist before its first Guardian's turn.
    var needsPiecesReminder: Bool { !piecesReady && !piecesReminderShown }
}

// MARK: - Access

enum Store {
    static let models: [any PersistentModel.Type] = [AppSettings.self]

    /// The single settings row, created on first use.
    @MainActor
    static func settings(in context: ModelContext) -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first { return existing }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
