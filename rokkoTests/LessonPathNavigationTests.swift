//
//  LessonPathNavigationTests.swift
//  Back and forth on the lesson path (Guardian): ‹ one step back, › one step ahead (skipping is
//  allowed), and tapping any part opens its first step.
//

import Foundation
import SwiftData
import Testing
import RokkoContent
@testable import rokko

@MainActor
@Suite(.serialized)
struct LessonPathNavigationTests {
    let library: ContentLibrary

    init() throws {
        library = try ContentLibrary(bundle: .main)
    }

    /// A coordinator on `stepId`, furthest step `furthestId` (default: the same). Keep the container alive.
    private func lesson(at stepId: String, furthest furthestId: String? = nil) throws -> (LessonCoordinator, ModelContainer) {
        let container = try ModelContainer(for: Schema(Store.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let settings = Store.settings(in: context)
        settings.calm = true
        settings.sound = false
        settings.piecesReady = true
        let progress = LessonProgress(lesson: library.lesson.lesson, stepId: stepId)
        progress.furthestStepId = furthestId
        context.insert(progress)
        let c = LessonCoordinator(library: library, settings: settings, context: context, onExit: {})
        c.start(getReady: false)
        return (c, container)
    }

    private func index(_ id: String) throws -> Int { try #require(library.lesson.index(of: id)) }

    @Test func pathPartsCoverEveryStepOnceInOrder() throws {
        let (c, container) = try lesson(at: "meet_king")
        _ = container
        let parts = c.pathSegments
        #expect(parts.first?.steps.lowerBound == 0)
        #expect(parts.last?.steps.upperBound == library.lesson.steps.count - 1)
        for (a, b) in zip(parts, parts.dropFirst()) {
            #expect(a.steps.upperBound + 1 == b.steps.lowerBound)
        }
        #expect(parts.map(\.id) == Array(parts.indices))
        #expect(parts.first?.kind == .story)
        #expect(parts.last?.kind == .finish)
        c.leaveLesson()
    }

    @Test func backThenForwardMovesOneStepEachWay() throws {
        let (c, container) = try lesson(at: "meet_rook")
        _ = container
        let start = c.stepIndex
        #expect(c.canGoBack)
        #expect(c.canGoForward, "› skips ahead (Guardian)")

        c.goBack()
        #expect(c.stepIndex == start - 1)
        #expect(c.lastMove == -1)

        c.goForward()
        #expect(c.stepIndex == start)
        #expect(c.lastMove == 1)

        // Past the furthest step: allowed, and the furthest step moves with it.
        c.goForward()
        #expect(c.stepIndex == start + 1)
        #expect(c.furthestIndex == start + 1)
        c.leaveLesson()
    }

    @Test func tappingAPartOpensItsFirstStepBackOrAhead() throws {
        let (c, container) = try lesson(at: "meet_knight")
        _ = container
        let parts = c.pathSegments
        let story = try #require(parts.first { $0.kind == .story })
        let games = try #require(parts.first { $0.kind == .games })
        let finish = try #require(parts.last)

        // Skip ahead to a game block never reached: its intro waits for Next, it does not move on.
        #expect(c.canOpen(games))
        c.open(games)
        #expect(c.stepIndex == games.steps.lowerBound)
        #expect(c.screen == .blockIntro || c.screen == .round)
        #expect(c.furthestIndex == games.steps.lowerBound)

        // Back to the film, then straight ahead again while its clip plays.
        c.open(story)
        #expect(c.stepIndex == 0)
        #expect(c.canOpen(finish))
        c.open(finish)
        #expect(c.stepIndex == finish.steps.lowerBound)
        #expect(!c.clipPlaying)
        #expect(!c.canOpen(finish), "the part on screen is not a target")
        c.leaveLesson()
    }

    @Test func thePathMovesOnFromABreak() throws {
        let (c, container) = try lesson(at: "break_1")
        _ = container
        let start = c.stepIndex
        #expect(c.screen == .breakPicker)
        #expect(c.canGoForward && c.canGoBack)
        c.goForward()
        #expect(c.stepIndex == start + 1)
        #expect(c.screen != .breakPicker && c.screen != .breakRunning)

        // Back into the break, start it, then skip on while it runs.
        c.goBack()
        #expect(c.screen == .breakPicker)
        c.next()
        #expect(c.screen == .breakRunning)
        c.goForward()
        #expect(c.stepIndex == start + 1)
        #expect(c.breakSecondsLeft(at: .now) == 0, "the skipped break's timer kept running")
        c.leaveLesson()
    }

    @Test func nextExtendsTheFurthestStep() throws {
        let (c, container) = try lesson(at: "meet_king")
        _ = container
        let start = c.stepIndex
        #expect(c.furthestIndex == start)
        c.next()
        #expect(c.stepIndex == start + 1)
        #expect(c.furthestIndex == start + 1)
        c.leaveLesson()
    }
}
