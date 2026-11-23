//
//  LessonCoordinator.swift
//  The state machine over lesson1.json (docs/ARCHITECTURE.md). Owns Next / Again / Done, the game
//  blocks (RoundPlanner → LevelSelector → RoundGenerator → RoundController), BKT, mood, breaks and
//  saving. Nothing advances on its own: every step waits for the Guardian's tap.
//
//  Clips (manifest.json) play in ClipPlayer; Calm and Reduce Motion get the calm file. A clip the
//  manifest names but the bundle lacks waits `story.clipPlaceholderSeconds` (0 = goes straight on).
//

import AVFoundation
import Foundation
import Observation
import SwiftData
import SpriteKit
import RokkoContent
import RokkoEngine

@MainActor
@Observable
final class LessonCoordinator: LessonEventSink {
    /// What fills the frame right now, inside the current step.
    enum Screen: Equatable {
        /// The step itself (film, meet, transform, Guardian's turn, play together, complete).
        case step
        /// Lesson's first Guardian's turn, once: are the six pieces out?
        case piecesCheck
        /// Game block intro line, before its first round.
        case blockIntro
        case round
        /// Inserted once before the first level-5 round.
        case charcoalIntro
        /// The block's rounds for this sitting are used up (ENGINE §4).
        case sittingFull
        case breakPicker
        case breakRunning
        case breakEnd
        /// After "complete": the Guardian summary in words.
        case summary
    }

    let library: ContentLibrary
    let settings: AppSettings
    private let context: ModelContext
    private let progress: LessonProgress
    private let onExit: () -> Void

    private(set) var stepIndex: Int
    private(set) var screen: Screen = .step
    /// Caption of a story or Guardian line; game rounds caption themselves.
    private(set) var storyCaption: String?
    /// A clip slot is showing (blank until the video arrives). Input waits for it.
    private(set) var clipPlaying = false
    /// Plays delivered clips; the clip view draws its player.
    let clipPlayer: ClipPlayer
    /// Subtitles of the clip in the slot (film clips with narration).
    private(set) var clipSubtitles: Subtitles?
    private(set) var round: RoundController?
    private(set) var guardianGlows = false
    var paused = false {
        didSet {
            round?.scene.isPaused = paused
            if paused { VoicePlayer.shared.pause() } else { VoicePlayer.shared.resume() }
            if paused { clipPlayer.pause() } else if clipPlaying, screen == .step { clipPlayer.resume() }
        }
    }
    var moodSheetShown = false
    private(set) var mood: Mood = .ready

    // Breaks
    var breakActivity: BreakActivity = .move
    var breakMinutes: Int
    private(set) var breakEnds: Date?
    private(set) var breakStarted: Date?
    private var screenBeforeBreak: Screen?
    private var breakIsPlanned = false

    // Engine
    private var learner: Learner
    private var planner: PlannerState
    private var planned: PlannedRound?
    private var plannedLevel = 1
    private var roundHadWrong = false
    @ObservationIgnored private var speakTask: Task<Void, Never>?
    @ObservationIgnored private var clipTask: Task<Void, Never>?
    @ObservationIgnored private var breakTask: Task<Void, Never>?

    var lesson: Lesson { library.lesson }
    var step: LessonStep { lesson.steps[stepIndex] }
    var config: EngineConfig { library.config }

    /// Calm look and sound: the Guardian's setting, or Wobbly (ENGINE §6).
    var calm: Bool { settings.calm || mood == .wobbly }

    init(library: ContentLibrary, settings: AppSettings, context: ModelContext, onExit: @escaping () -> Void) {
        self.library = library
        self.settings = settings
        self.context = context
        self.onExit = onExit
        let progress = Store.progress(lesson: library.lesson.lesson, firstStep: library.lesson.steps[0].id, in: context)
        self.progress = progress
        breakMinutes = library.config.breaks.defaultMinutes
        clipPlayer = ClipPlayer(tickSeconds: library.config.story.subtitleTickMs / 1000)

        // BKT and planner come back exactly as they were saved.
        var start: [Skill: Double] = [:]
        for row in Store.skills(in: context) { if let s = Skill(rawValue: row.skillRaw) { start[s] = row.p } }
        learner = Learner(library.config, start: start, responseTimes: progress.responseTimes)
        var state = progress.plannerData.flatMap { try? JSONDecoder().decode(PlannerState.self, from: $0) } ?? PlannerState()
        state.newSitting()
        planner = state
        mood = progress.wobbly ? .wobbly : .ready

        var index = library.lesson.index(of: progress.stepId) ?? 0
        // Lesson 1 stays playable as practice after it is complete (FR-33).
        if progress.completed, library.lesson.steps[index].kind == .complete { index = 0 }
        #if DEBUG
        // `-RokkoLessonStep game_m1` opens that step.
        if let id = UserDefaults.standard.string(forKey: "RokkoLessonStep"), let i = library.lesson.index(of: id) { index = i }
        #endif
        stepIndex = index
    }

    /// Opens the saved step. Called once, when the lesson is on screen (LessonContainer), never from
    /// `init`: SwiftUI may build and throw away extra coordinators, and those must not play anything.
    func start() {
        guard !started else { return }
        started = true
        enterStep()
        #if DEBUG
        // `-RokkoCharcoalIntro animals|pieces|guardian` opens the black team intro at that stage.
        switch UserDefaults.standard.string(forKey: "RokkoCharcoalIntro") {
        case "animals": charcoalStage = .animals; screen = .charcoalIntro
        case "pieces": charcoalStage = .pieces; screen = .charcoalIntro
        case "guardian": charcoalStage = .guardian; screen = .charcoalIntro
        default: break
        }
        #endif
    }

    @ObservationIgnored private var started = false

    // MARK: What the step shows

    /// meet: the animal; transform: the animal of the meet step before it.
    var stepAnimal: Animal? {
        for s in lesson.steps[...stepIndex].reversed() {
            if let a = s.animal.flatMap(Animal.init(rawValue:)) { return a }
        }
        return nil
    }

    /// transform: the piece the animal becomes.
    var stepPiece: Piece? {
        step.piece ?? stepAnimal.flatMap { a in Piece.allCases.first { $0.animal == a.rawValue } }
    }

    /// Game block intro: the module's animals (all six in a module without Type 1/2 pieces).
    var blockAnimals: [Animal] {
        let pieces = library.planner.pieces(module: module)
        let list = pieces.isEmpty ? Piece.allCases : pieces
        return list.compactMap { Animal(rawValue: $0.animal) }
    }

    // MARK: Lesson path

    /// The lesson path pill: one dot per part of the lesson (story, meet, games, break, …).
    var pathParts: (done: Int, total: Int) {
        var parts: [String] = []
        var current = 0
        var lastModule = 0
        for (i, s) in lesson.steps.enumerated() {
            let key: String
            switch s.kind {
            case .film: key = "film"
            case .meet, .transform, .guardianShow: key = "meet"
            case .gameBlock:
                lastModule = s.module ?? lastModule
                key = "game\(lastModule)"
            // The module's Guardian's turn belongs to the games before it.
            case .guardianModule, .charcoalIntro: key = "game\(lastModule)"
            case .break: key = "break"
            case .playTogether, .complete: key = "end"
            }
            if parts.last != key { parts.append(key) }
            if i == stepIndex { current = parts.count - 1 }
        }
        return (current, parts.count)
    }

    // MARK: Steps

    private func enterStep() {
        stopSpeaking()
        clipTask?.cancel()
        clipPlayer.stop()
        clipSubtitles = nil
        clipPlaying = false
        round?.stop()
        round = nil
        screen = .step
        progress.stepId = step.id
        save()

        switch step.kind {
        case .film:
            playClip(step.clip, then: nil)
        case .meet:
            speak(step.voice)
        case .transform:
            playClip(step.clip) { [weak self] in self?.speak(self?.step.voice ?? []) }
        case .guardianShow:
            if settings.needsPiecesReminder { screen = .piecesCheck }
        case .guardianModule, .complete:
            if step.kind == .complete { speak(step.voice) }
        case .playTogether:
            speak(step.voice)
        case .gameBlock:
            enterBlock()
        case .charcoalIntro:
            playClip(step.clip) { [weak self] in self?.speak(self?.step.voice ?? []) }
        case .break:
            breakIsPlanned = true
            openBreakPicker()
        }
    }

    private func advanceStep() {
        guard stepIndex + 1 < lesson.steps.count else { exit(); return }
        stepIndex += 1
        enterStep()
    }

    // MARK: Guardian taps

    /// Next / Done in the bottom band.
    func next() {
        guard !clipPlaying else { return }
        switch screen {
        case .step:
            if step.kind == .complete { stopSpeaking(); screen = .summary; return }
            advanceStep()
        case .piecesCheck:
            settings.piecesReminderShown = true
            save()
            screen = .step
        case .blockIntro:
            startRound()
        case .round:
            guard round?.isFinished == true else { return }
            finishRound()
        case .charcoalIntro:
            switch charcoalStage {
            case .animals:
                charcoalStage = .pieces
                speak([VoiceKeys.charcoalPieces])
            case .pieces:
                stopSpeaking()
                charcoalStage = .guardian
            case .guardian:
                progress.charcoalIntroSeen = true
                save()
                buildRound()
            }
        case .sittingFull:
            break   // two choices on screen
        case .breakPicker:
            startBreak()
        case .breakRunning:
            endBreak()
        case .breakEnd:
            leaveBreak()
        case .summary:
            progress.completed = true
            save()
            exit()
        }
    }

    /// Again (↻): replays the clip of this step (film clip or transformation), from the start.
    func again() {
        guard !clipPlaying, screen == .step, step.again else { return }
        switch step.kind {
        case .film: playClip(step.clip, then: nil)
        case .transform: playClip(step.clip) { [weak self] in self?.speak(self?.step.voice ?? []) }
        default: break
        }
    }

    /// Whether Next can be tapped now.
    var nextEnabled: Bool {
        if clipPlaying { return false }
        if screen == .round { return round?.isFinished == true }
        return true
    }

    var nextKind: LessonNextButton.Kind {
        switch screen {
        case .step:
            switch step.kind {
            case .guardianShow, .guardianModule, .playTogether: return .done
            default: return .next
            }
        case .piecesCheck, .breakRunning, .summary: return .done
        case .charcoalIntro where charcoalStage == .guardian: return .done
        default: return .next
        }
    }

    /// Again shows only where a clip can be replayed.
    var showsAgain: Bool {
        screen == .step && (step.kind == .transform || step.kind == .film) && step.again && !clipPlaying
    }

    var isGuardianSurface: Bool {
        switch screen {
        case .piecesCheck, .sittingFull, .breakPicker, .summary: return true
        case .charcoalIntro: return charcoalStage == .guardian
        case .step: return [.guardianShow, .guardianModule, .playTogether].contains(step.kind)
        default: return false
        }
    }

    func leaveLesson() {
        paused = false
        exit()
    }

    private func exit() {
        stopSpeaking()
        clipTask?.cancel()
        clipPlayer.stop()
        breakTask?.cancel()
        round?.stop()
        save()
        onExit()
    }

    // MARK: Clips (blank until the video team delivers them)

    private func playClip(_ id: String?, then: (() -> Void)?) {
        clipTask?.cancel()
        // Again on a transformation: its line must not talk over the replayed clip.
        stopSpeaking()
        clipPlaying = true
        clipSubtitles = id.flatMap(library.subtitles(for:))
        // Delivered clip: play it; the lesson waits for its end (and then for Next).
        // Calm mode, a wobbly mood and iOS Reduce Motion all get the calm file (a plain cross-fade).
        if let id, let url = library.clipURL(id, calm: calm || reduceMotion) {
            let still = library.manifest.clip(id)?.endStill
            clipPlayer.play(url, muted: !settings.sound) { [weak self] in
                guard let self else { return }
                if let still { self.clipPlayer.hold(at: still) }
                self.clipPlaying = false
                then?()
            }
            if paused { clipPlayer.pause() }
            return
        }
        // Not delivered yet: no blank card; go straight on (the "after" picture and its line).
        if config.story.clipPlaceholderSeconds <= 0 {
            clipPlaying = false
            then?()
            return
        }
        let seconds = id.flatMap { library.manifest.clip($0)?.seconds } ?? config.story.clipPlaceholderSeconds
        clipTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            self.clipPlaying = false
            then?()
        }
    }

    // MARK: Captions (lines in a row, each held until it has typed out)

    private func speak(_ keys: [String]) {
        stopSpeaking()
        let lines = keys.compactMap { library.caption($0) }
        guard let first = lines.first else { return }
        storyCaption = first
        // Recorded lines: each caption shows while its line plays.
        let played = VoicePlayer.shared.play(keys, gapSeconds: config.story.voiceGapMs / 1000,
                                             onLine: { [weak self] i in
                                                 if i < lines.count { self?.storyCaption = lines[i] }
                                             })
        guard !played, lines.count > 1 else { return }
        // No recording yet: lines follow each other on a timer.
        let charSeconds = config.motion.captionCharMs / 1000
        let hold = config.story.captionHoldMs / 1000
        speakTask = Task { @MainActor [weak self] in
            for (i, line) in lines.enumerated() where i > 0 {
                let previous = lines[i - 1]
                try? await Task.sleep(for: .seconds(Double(previous.count) * charSeconds + hold))
                guard let self, !Task.isCancelled else { return }
                self.storyCaption = line
            }
        }
    }

    private func stopSpeaking() {
        VoicePlayer.shared.stop()
        speakTask?.cancel()
        speakTask = nil
        storyCaption = nil
    }

    /// The caption shown in the bottom band.
    var caption: String? { screen == .round ? round?.caption : (subtitle ?? storyCaption) }

    /// The film subtitle on screen now: one line at a time, only while the clip plays.
    var subtitle: String? { subtitleCue?.text }

    /// Film steps with a delivered clip: the video fills the screen (and stays on its last frame at the end).
    var fullScreenVideo: AVPlayer? {
        guard screen == .step, step.kind == .film, clipPlayer.hasClip else { return nil }
        return clipPlayer.player
    }

    private var subtitleCue: Subtitles.Cue? {
        guard clipPlaying, screen == .step, let clipSubtitles else { return nil }
        return clipSubtitles.cue(at: clipPlayer.time)
    }

    /// Film line: how much of it the voice has said so far (word by word, from the clip time).
    var captionShown: Int? {
        subtitleCue?.shownCharacters(at: clipPlayer.time)
    }

    /// A film clip has played to its end: its last picture stays, marked Finished, until Next or Again.
    var filmFinished: Bool { fullScreenVideo != nil && !clipPlaying }

    /// The app went to the background (AVPlayer pauses itself) or came back.
    func sceneActive(_ active: Bool) {
        if !active { clipPlayer.pause() }
        else if clipPlaying, screen == .step, !paused { clipPlayer.resume() }
    }

    // MARK: Game blocks

    private var module: Int { step.module ?? 1 }
    private var gate: EngineConfig.Gate? { step.gate.flatMap { config.gates[$0] } }
    private func known(_ s: Skill) -> Double { learner.known(s) }

    private func enterBlock() {
        if library.planner.blockEnds(module: module, gate: gate, state: planner, known: known) {
            // Resumed after the gate was already met.
            endBlock()
            return
        }
        if planner.roundsInBlock == 0, let intro = step.intro {
            screen = .blockIntro
            speak([intro])
        } else {
            startRound()
        }
    }

    private func startRound() {
        stopSpeaking()
        let plan = library.planner.next(module: module, state: planner, known: known)
        planned = plan
        let state = Store.exercise(plan.exerciseCode, in: context)
        let p = library.planner.levelSkillP(type: plan.type, piece: plan.piece, known: known)
        let level = LevelSelector(config.levels).level(p: p, lastLevel: state.lastLevel, colour: known(.colour),
                                                      charcoalIntroSeen: true, wobbly: mood == .wobbly)
        plannedLevel = level
        // The first round that shows anything black: the black team is introduced first, once (FR-13).
        if !progress.charcoalIntroSeen, charcoalIntro != nil, nextRoundShowsBlack() {
            charcoalStage = .animals
            screen = .charcoalIntro
            speak(charcoalIntro?.voice ?? [])
            return
        }
        buildRound()
    }

    /// The black team intro (lesson1.json › inserted). Its video (L1_CH01) is not waited for:
    /// the intro is shown on screen, step by step.
    private var charcoalIntro: LessonStep? { lesson.inserted.values.first { $0.kind == .charcoalIntro } }

    /// What the black team intro is showing.
    enum CharcoalStage { case animals, pieces, guardian }
    private(set) var charcoalStage: CharcoalStage = .animals

    private func nextRoundShowsBlack() -> Bool {
        guard let plan = planned, let exercise = library.pool.exercise(plan.exerciseCode),
              let r = RoundPlanner.round(in: exercise, level: plannedLevel,
                                         plays: Store.exercise(plan.exerciseCode, in: context).plays(at: plannedLevel))
        else { return false }
        let items: [Item] = switch r.content {
        case .choice(let c): [c.shown, c.answer] + c.options
        case .link(let l): l.characters + l.pieces
        case .shelf(let s): s.toPlace + s.prefilled + s.distractors
        case .teams(let t): [t.blackKing] + t.toPlace
        }
        return items.contains { $0.colour == .black }
    }

    private func buildRound() {
        stopSpeaking()
        guard let plan = planned, let exercise = library.pool.exercise(plan.exerciseCode) else { return }
        let state = Store.exercise(plan.exerciseCode, in: context)
        guard let poolRound = RoundPlanner.round(in: exercise, level: plannedLevel, plays: state.plays(at: plannedLevel)) else { return }
        let spec = library.generator.spec(for: poolRound, type: exercise.type, previousAnswerSlot: progress.lastAnswerSlot)
        if case .choice(let c) = spec.body { progress.lastAnswerSlot = c.answerSlot }
        roundHadWrong = false
        let motion = SceneMotion(config, calm: calm, reduceMotion: reduceMotion)
        let idle = HintLadder.idleSeconds(config.hints, calmOrWobbly: calm)
        let code = spec.id
        round = RoundController(spec: spec, library: library, motion: motion, idleSeconds: idle) { [weak self] result in
            self?.record(result, code: code)
        }
        screen = .round
    }

    /// Set by the container from the environment.
    var reduceMotion = false

    private func record(_ result: TargetResult, code: String) {
        let evidence = learner.record(result, wobbly: mood == .wobbly)
        if !result.correct || result.hint != .none { roundHadWrong = true }
        let row = Store.skills(in: context).first { $0.skillRaw == result.skill.rawValue }
            ?? { let r = SkillState(skill: result.skill.rawValue, p: 0); context.insert(r); return r }()
        row.p = learner.known(result.skill)
        row.attempts += 1
        row.lastPractised = .now
        let outcome: String = switch evidence {
        case .correct: "correct"
        case .incorrect: "incorrect"
        case .ignored: "ignored"
        }
        context.insert(SessionEvent(code: code, skill: result.skill.rawValue, outcome: outcome,
                                    hintLevel: result.hint.rawValue, responseMs: result.responseMs, mood: mood.rawValue))
        progress.responseTimes = learner.responseTimes.times
    }

    private func finishRound() {
        guard let plan = planned else { return }
        if let round, round.answers.contains(where: { $0.outcome == .tryAgain }) { roundHadWrong = true }
        library.planner.played(plan, state: &planner)
        Store.exercise(plan.exerciseCode, in: context).played(at: plannedLevel)
        progress.roundsWithWrong = Array((progress.roundsWithWrong + [roundHadWrong]).suffix(20))
        let last = round?.results.compactMap(\.responseMs).last
        guardianGlows = SignalMonitor(config.signal).suggestsCheckIn(
            roundsWithWrong: progress.roundsWithWrong, lastResponseMs: last, medianMs: learner.responseTimes.median)
        Store.trimEvents(to: config.storage.maxSessionEvents, in: context)
        save()

        round?.stop()
        round = nil
        if library.planner.blockEnds(module: module, gate: gate, state: planner, known: known) {
            endBlock()
        } else if library.planner.sittingFull(module: module, state: planner) {
            screen = .sittingFull
        } else {
            startRound()
        }
    }

    private func endBlock() {
        planner = PlannerState()
        save()
        advanceStep()
    }

    #if DEBUG
    /// Developer only: ends this round now (no BKT update for what is left) and moves on.
    func devSkipRound() {
        guard screen == .round else { return }
        finishRound()
    }
    #endif

    /// Sitting full: "Stop here for today" (resume in this block next time) or "Keep going".
    func stopForToday() { exit() }

    func keepGoing() {
        planner.newSitting()
        startRound()
    }

    // MARK: Mood (set only by the Guardian)

    func lessonFrame(didReport event: LessonFrameEvent) {
        guard case .moodChosen(let picked) = event else { return }
        guardianGlows = false
        switch picked {
        case .ready:
            mood = .ready
            progress.wobbly = false
        case .wobbly:
            mood = .wobbly
            progress.wobbly = true
        case .needsBreak:
            breakIsPlanned = false
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(RokkoMotion.moodSheetCloseDelay))
                self?.openBreakPicker()
            }
        }
        save()
    }

    // MARK: Breaks (FR-28, FR-29)

    private func openBreakPicker() {
        if screen != .breakPicker && screen != .breakRunning && screen != .breakEnd { screenBeforeBreak = screen }
        round?.scene.isPaused = true
        clipPlayer.pause()
        stopSpeaking()
        breakMinutes = config.breaks.defaultMinutes
        screen = .breakPicker
    }

    private func startBreak() {
        screen = .breakRunning
        speak([VoiceKeys.breakStart] + (breakActivity.voiceKey.map { [$0] } ?? []))
        breakStarted = .now
        breakEnds = Date.now.addingTimeInterval(Double(breakMinutes) * 60)
        scheduleBreakEnd()
    }

    /// Leaf timer: share of the break still to go (1 → 0).
    func breakFractionLeft(at now: Date) -> Double {
        guard screen == .breakRunning, let start = breakStarted, let ends = breakEnds else { return 0 }
        let total = ends.timeIntervalSince(start)
        return total > 0 ? min(1, max(0, ends.timeIntervalSince(now) / total)) : 0
    }

    /// Whole seconds of the break still to go, for the Guardian's countdown.
    func breakSecondsLeft(at now: Date) -> Int {
        guard screen == .breakRunning, let ends = breakEnds else { return 0 }
        return max(0, Int(ends.timeIntervalSince(now).rounded(.up)))
    }

    /// Goes up by one each time time is added; the break view animates on change.
    private(set) var breakTimeAdded = 0

    func addBreakMinute() {
        breakEnds = (breakEnds ?? .now).addingTimeInterval(Double(config.breaks.addMinutes) * 60)
        breakTimeAdded += 1
        scheduleBreakEnd()
    }

    private func scheduleBreakEnd() {
        breakTask?.cancel()
        guard let ends = breakEnds else { return }
        breakTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(0, ends.timeIntervalSinceNow)))
            guard let self, !Task.isCancelled, self.screen == .breakRunning else { return }
            self.endBreak()
        }
    }

    private func endBreak() {
        breakTask?.cancel()
        breakEnds = nil
        progress.breaksTaken += 1
        // Wobbly lasts until a break ends.
        mood = .ready
        progress.wobbly = false
        save()
        screen = .breakEnd
        speak([VoiceKeys.breakEnd])
    }

    private func leaveBreak() {
        stopSpeaking()
        if breakIsPlanned {
            breakIsPlanned = false
            advanceStep()
            return
        }
        // Back exactly where the Guardian asked for the break.
        let back = screenBeforeBreak ?? .step
        screenBeforeBreak = nil
        round?.scene.isPaused = false
        screen = back
        if back == .step, clipPlaying { clipPlayer.resume() }
        if back == .step, step.kind == .meet || step.kind == .transform { speak(step.voice) }
        if back == .blockIntro, let intro = step.intro { speak([intro]) }
    }

    // MARK: Summary (words only, FR-32)

    var summaryLines: [String] {
        let mastered = config.levels.mastered
        let midway = config.gates["module2"]?.min ?? 0.6
        var lines = Piece.allCases.map { piece -> String in
            let p = known(Skill(piece))
            if p >= mastered { return "Knows the \(piece.displayName) well" }
            if p >= midway { return "Is getting to know the \(piece.displayName)" }
            return "Still learning the \(piece.displayName)"
        }
        if config.gates["lessonComplete"]?.skills.contains(.colour) == true {
            lines.append(known(.colour) >= mastered ? "Tells the white and black teams apart" : "Still learning the two teams")
        }
        // Team make-up only when the shelf game is played (it is the only game that teaches it).
        if config.gates["lessonComplete"]?.skills.contains(.teamMakeup) == true {
            lines.append(known(.teamMakeup) >= mastered ? "Knows the pieces of a team" : "Still learning what is in a team")
        }
        switch progress.breaksTaken {
        case 0: lines.append("No breaks taken")
        case 1: lines.append("Took one break")
        default: lines.append("Took \(progress.breaksTaken) breaks")
        }
        return lines
    }

    // MARK: Saving

    private func save() {
        progress.plannerData = try? JSONEncoder().encode(planner)
        try? context.save()
    }
}

/// The four break activities (FR-28).
enum BreakActivity: String, CaseIterable, Identifiable {
    case move, breathe, quiet, ownIdea

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: "Move like the animals"
        case .breathe: "Breathe with the lion"
        case .quiet: "Quiet time"
        case .ownIdea: "Your own idea"
        }
    }

    /// The character who models it.
    var animal: Animal {
        switch self {
        case .move: .elephant
        case .breathe: .lion
        case .quiet: .squirrel
        case .ownIdea: .horse
        }
    }

    var voiceKey: String? {
        switch self {
        case .move: VoiceKeys.breakMove
        case .breathe: VoiceKeys.breakBreathe
        case .quiet: VoiceKeys.breakQuiet
        case .ownIdea: nil
        }
    }
}
