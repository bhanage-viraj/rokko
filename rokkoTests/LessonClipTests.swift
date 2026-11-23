//
//  LessonClipTests.swift
//  The lesson's clips through the real LessonCoordinator and ClipPlayer (in-memory store, no view):
//  the right file for Calm / Standard / Reduce Motion, input locked while a clip plays, nothing
//  advancing on its own at the end, Again replaying, and pause / background never leaving sound
//  running without its picture.
//

import AVFoundation
import Foundation
import SwiftData
import Testing
import RokkoContent
@testable import rokko

@MainActor
@Suite(.serialized)
struct LessonClipTests {
    let library: ContentLibrary

    init() throws {
        library = try ContentLibrary(bundle: .main)
    }

    /// A coordinator that opens `stepId`. Keep the container alive for as long as the coordinator.
    private func lesson(at stepId: String, calm: Bool, reduceMotion: Bool = false) throws -> (LessonCoordinator, ModelContainer) {
        let container = try ModelContainer(for: Schema(Store.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let settings = Store.settings(in: context)
        settings.calm = calm
        settings.sound = false
        settings.piecesReady = true
        context.insert(LessonProgress(lesson: library.lesson.lesson, stepId: stepId))
        let c = LessonCoordinator(library: library, settings: settings, context: context, onExit: {})
        c.reduceMotion = reduceMotion
        c.start(getReady: false)
        return (c, container)
    }

    private func loadedFile(_ c: LessonCoordinator) -> String? {
        (c.clipPlayer.player.currentItem?.asset as? AVURLAsset)?.url.lastPathComponent
    }

    /// Waits (real time) until the clip has played to its end.
    private func waitForClipEnd(_ c: LessonCoordinator, clip: String) async throws {
        let seconds = try #require(library.manifest.clip(clip)?.seconds)
        let deadline = Date.now.addingTimeInterval(seconds + 5)
        while c.clipPlaying && Date.now < deadline { try await Task.sleep(for: .milliseconds(100)) }
        #expect(!c.clipPlaying, "\(clip) never reached its end")
    }

    private var transformSteps: [LessonStep] { library.lesson.steps.filter { $0.kind == .transform } }

    // MARK: Which file

    @Test(arguments: [(calm: true, reduceMotion: false, suffix: "_calm.mp4"),
                      (calm: false, reduceMotion: false, suffix: "_standard.mp4"),
                      (calm: false, reduceMotion: true, suffix: "_calm.mp4"),
                      (calm: true, reduceMotion: true, suffix: "_calm.mp4")])
    func transformPlaysTheFileForTheLook(calm: Bool, reduceMotion: Bool, suffix: String) throws {
        #expect(transformSteps.count == 6)
        for step in transformSteps {
            let (c, container) = try lesson(at: step.id, calm: calm, reduceMotion: reduceMotion)
            _ = container
            let clip = try #require(step.clip)
            // Delivered: it plays (story.clipPlaceholderSeconds = 0 must not skip it).
            #expect(c.clipPlaying, "\(step.id) did not play")
            #expect(c.clipPlayer.hasClip, "\(step.id) has no clip loaded")
            #expect(loadedFile(c) == "\(clip)\(suffix)", "\(step.id): loaded \(loadedFile(c) ?? "nothing")")
            c.leaveLesson()
        }
    }

    @Test func filmPlaysFullScreenWithSubtitles() throws {
        for step in library.lesson.steps where step.kind == .film {
            for calm in [true, false] {
                let (c, container) = try lesson(at: step.id, calm: calm)
                _ = container
                #expect(c.clipPlaying, "\(step.id)")
                #expect(c.fullScreenVideo != nil, "\(step.id): not full screen")
                #expect(loadedFile(c) == "\(step.clip ?? "").mp4", "\(step.id)")
                #expect(library.subtitles(for: step.clip ?? "") != nil, "\(step.id): no subtitles")
                c.leaveLesson()
            }
        }
    }

    // MARK: Input lock, end, Again

    @Test func transformLocksInputThenWaitsForNext() async throws {
        let step = try #require(transformSteps.first)
        let (c, container) = try lesson(at: step.id, calm: false)
        _ = container
        let index = c.stepIndex

        // Playing: no Next, no Again, taps do nothing.
        #expect(!c.nextEnabled)
        #expect(!c.showsAgain)
        c.next()
        c.again()
        #expect(c.stepIndex == index)
        #expect(c.clipPlaying)

        try await waitForClipEnd(c, clip: step.clip!)

        // The end: the "after" picture and its line; Next and Again on; the step stays.
        #expect(c.nextEnabled)
        #expect(c.showsAgain)
        #expect(c.stepIndex == index, "a transformation must not advance by itself")
        #expect(c.caption != nil, "the transformation line did not start")

        // Again: the same clip from the start, input locked again, and the line stops while it plays.
        c.again()
        #expect(c.clipPlaying)
        #expect(!c.nextEnabled)
        #expect(loadedFile(c) == "\(step.clip!)_standard.mp4")
        #expect(c.caption == nil, "the voice line kept talking over the replayed clip")
        try await waitForClipEnd(c, clip: step.clip!)
        #expect(c.stepIndex == index)
        c.leaveLesson()
    }

    /// The shortest film clip, played to its end: it stays on its end still, Finished, until Next.
    @Test func filmHoldsItsEndStillUntilNext() async throws {
        let films = library.lesson.steps.filter { $0.kind == .film }
        let step = try #require(films.min { (library.manifest.clip($0.clip!)?.seconds ?? 0) < (library.manifest.clip($1.clip!)?.seconds ?? 0) })
        let clip = try #require(library.manifest.clip(step.clip!))
        let (c, container) = try lesson(at: step.id, calm: true)
        _ = container
        #expect(!c.filmFinished)
        try await waitForClipEnd(c, clip: clip.id)

        #expect(c.filmFinished, "no Finished state")
        #expect(c.fullScreenVideo != nil, "the picture went away at the end")
        #expect(c.nextEnabled && c.showsAgain)
        #expect(c.subtitle == nil, "a subtitle stays after the clip")
        try await Task.sleep(for: .milliseconds(500))
        let still = try #require(clip.endStill)
        let shown = c.clipPlayer.player.currentTime().seconds
        #expect(abs(shown - still) < 0.05, "holds at \(shown), endStill is \(still)")
        #expect(c.clipPlayer.player.rate == 0)
        #expect(c.stepIndex == library.lesson.index(of: step.id))

        c.again()
        #expect(c.clipPlaying && !c.filmFinished)
        #expect(c.clipPlayer.player.currentTime().seconds < 1)
        c.leaveLesson()
    }

    // MARK: Pause and background

    @Test func pauseAndBackgroundStopTheClipAndResumeOnce() async throws {
        let step = try #require(library.lesson.steps.first { $0.kind == .film })
        let (c, container) = try lesson(at: step.id, calm: true)
        _ = container
        let player = c.clipPlayer.player
        try await Task.sleep(for: .milliseconds(300))
        #expect(player.rate > 0)

        c.paused = true
        #expect(player.rate == 0)
        // Leaving and coming back while paused: still paused (the Guardian resumes, not the app).
        c.sceneActive(false)
        c.sceneActive(true)
        #expect(player.rate == 0)
        c.paused = false
        #expect(player.rate > 0)

        // Background while playing: sound and picture stop together, and come back once.
        c.sceneActive(false)
        #expect(player.rate == 0)
        let at = player.currentTime().seconds
        c.sceneActive(true)
        c.sceneActive(true)
        #expect(player.rate == 1, "played at rate \(player.rate)")
        #expect(abs(player.currentTime().seconds - at) < 0.5, "jumped from \(at)")

        // Leaving the lesson leaves nothing playing.
        c.leaveLesson()
        #expect(player.rate == 0)
        #expect(player.currentItem == nil)
    }
}
