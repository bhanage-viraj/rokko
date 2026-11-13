//
//  OnboardingViewModelTests.swift
//  Step order, Back, Skip defaults, Continue rules, saved values, practice mode, hold timing.
//

import Testing
import SwiftData
@testable import rokko

@MainActor
struct OnboardingViewModelTests {

    typealias Step = OnboardingViewModel.Step

    // MARK: Step order and progress

    @Test func stepOrder() {
        #expect(Step.allCases == [.welcome, .chess, .look, .tryGuardian, .tryCheckIn, .ready])
    }

    @Test func progressCountsFourStepsAndSkipsWelcomeAndReady() {
        let vm = OnboardingViewModel()
        #expect(vm.progressNumber == nil)
        #expect(vm.progressLabel == "About 1 minute")
        vm.next()
        #expect(vm.step == .chess)
        #expect(vm.progressLabel == "Step 1 of 4")
        #expect(vm.progressShort == "1 of 4")
        #expect(OnboardingViewModel(startAt: .look).progressShort == "2 of 4")
        #expect(OnboardingViewModel(startAt: .tryCheckIn).progressLabel == "Step 4 of 4")
        let ready = OnboardingViewModel(startAt: .ready)
        #expect(ready.progressNumber == nil)
        #expect(ready.progressLabel == "Done")
    }

    @Test func walkingThroughEveryStepInOrder() {
        let vm = OnboardingViewModel()
        vm.next()                            // welcome → chess
        vm.chess = .yes; vm.next()           // → look
        vm.look = .standard; vm.next()       // → tryGuardian
        vm.tryGuardianDone = true; vm.next() // → tryCheckIn
        vm.practiceMood = .wobbly; vm.next() // → ready
        #expect(vm.step == .ready)
    }

    // MARK: Back / Skip visibility

    @Test func fullScreenSteps() {
        for step in Step.allCases {
            let full = [.look, .tryGuardian, .tryCheckIn].contains(step)
            #expect(OnboardingViewModel(startAt: step).isFullScreen == full, "\(step)")
            #expect(OnboardingViewModel(startAt: step).showsTopBar == (step != .ready), "\(step)")
        }
    }

    @Test func backAndSkipVisibility() {
        let welcome = OnboardingViewModel()
        #expect(!welcome.showsBack)
        #expect(welcome.showsSkip)
        for step in Step.allCases where step != .welcome && step != .ready {
            let vm = OnboardingViewModel(startAt: step)
            #expect(vm.showsBack, "Back on \(step)")
            #expect(vm.showsSkip, "Skip on \(step)")
        }
        let ready = OnboardingViewModel(startAt: .ready)
        #expect(!ready.showsBack)
        #expect(!ready.showsSkip)
    }

    @Test func backGoesToPreviousStepAndKeepsAnswers() {
        let vm = OnboardingViewModel(startAt: .look)
        vm.look = .standard
        vm.back()
        #expect(vm.step == .chess)
        vm.chess = .aLittle
        vm.next()
        #expect(vm.step == .look)
        #expect(vm.look == .standard)
    }

    @Test func goingBackIntoAPracticeStepResetsIt() {
        let vm = OnboardingViewModel(startAt: .tryGuardian)
        vm.tryGuardianDone = true
        vm.next()
        vm.practiceMood = .ready
        vm.back()                                   // tryCheckIn → tryGuardian
        #expect(vm.step == .tryGuardian)
        #expect(!vm.tryGuardianDone)
        #expect(!vm.canContinue)
    }

    @Test func onlyTheCheckInAutoAdvances() {
        for step in OnboardingViewModel.Step.allCases {
            #expect(OnboardingViewModel(startAt: step).autoAdvances == (step == .tryCheckIn), "\(step)")
        }
    }

    @Test func backDoesNothingOnWelcomeOrReady() {
        let welcome = OnboardingViewModel()
        welcome.back()
        #expect(welcome.step == .welcome)
        let ready = OnboardingViewModel(startAt: .ready)
        ready.back()
        #expect(ready.step == .ready)
    }

    // MARK: Continue rules

    @Test func continueWaitsForEachStepsAction() {
        let look = OnboardingViewModel(startAt: .look)
        #expect(!look.canContinue)
        look.next()
        #expect(look.step == .look, "Continue must not move while disabled")
        look.look = .calm
        #expect(look.canContinue)

        let chess = OnboardingViewModel(startAt: .chess)
        #expect(!chess.canContinue)
        chess.chess = .notYet
        #expect(chess.canContinue)

        let tryGuardian = OnboardingViewModel(startAt: .tryGuardian)
        #expect(!tryGuardian.canContinue)
        tryGuardian.tryGuardianDone = true
        #expect(tryGuardian.canContinue)

        let checkIn = OnboardingViewModel(startAt: .tryCheckIn)
        #expect(!checkIn.canContinue)
        checkIn.practiceMood = .ready
        #expect(checkIn.canContinue)
    }

    // MARK: What gets saved

    @Test func skipWaitsForChessAndLook() {
        let vm = OnboardingViewModel()
        #expect(!vm.canSkip)
        vm.skip()
        #expect(vm.step == .welcome, "Skip does nothing before the two answers")
        vm.next()
        vm.chess = .notYet
        #expect(!vm.canSkip)
        vm.skip()
        #expect(vm.step == .chess)
        vm.next()
        vm.look = .calm
        #expect(vm.canSkip)
        vm.skip()
        #expect(vm.step == .ready)
        #expect(vm.result == .init(calm: true, tipsMode: .full))
    }

    @Test func skipKeepsAnswersAlreadyGiven() {
        let vm = OnboardingViewModel(startAt: .chess)
        vm.chess = .yes
        vm.next()
        vm.look = .standard
        vm.skip()
        #expect(vm.result == .init(calm: false, tipsMode: .short))
    }

    @Test(arguments: [
        (OnboardingViewModel.ChessExperience.notYet, TipsMode.full),
        (.aLittle, .short),
        (.yes, .short),
    ])
    func chessAnswerSetsTipsMode(answer: OnboardingViewModel.ChessExperience, expected: TipsMode) {
        let vm = OnboardingViewModel(startAt: .chess)
        vm.chess = answer
        #expect(vm.tipsMode == expected)
    }

    @Test func lookAnswerSetsCalm() {
        let vm = OnboardingViewModel(startAt: .look)
        vm.look = .standard
        #expect(vm.result.calm == false)
        vm.look = .calm
        #expect(vm.result.calm == true)
    }

    @Test func saveWritesSettingsAndLeavesPiecesForTheLesson() throws {
        let container = try ModelContainer(for: AppSettings.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let settings = Store.settings(in: container.mainContext)
        #expect(!settings.onboardingDone)

        let vm = OnboardingViewModel(startAt: .chess)
        vm.chess = .aLittle
        vm.next()
        vm.look = .standard
        vm.skip()
        vm.save(to: settings)

        #expect(settings.onboardingDone)
        #expect(settings.calm == false)
        #expect(settings.tipsMode == .short)
        #expect(settings.piecesReady == false)
        #expect(settings.needsPiecesReminder, "The lesson shows the pieces checklist once")
    }

    @Test func summaryChips() {
        let vm = OnboardingViewModel()
        vm.chess = .notYet
        vm.look = .calm
        vm.skip()
        #expect(vm.summaryChips == ["Calm look", "Full tips"])
    }
}

// MARK: - Guardian button hold

struct HoldProgressTests {

    @Test func releasingEarlyStopsWhereTheFingerLeft() {
        let half = HoldProgress(elapsed: 1.0, holdSeconds: 2)
        #expect(half.fraction == 0.5)
        #expect(!half.isComplete)

        let quick = HoldProgress(elapsed: 0.3, holdSeconds: 2)
        #expect(abs(quick.fraction - 0.15) < 0.0001)
        #expect(!quick.isComplete)
    }

    @Test func holdingTheFullTimeCompletes() {
        #expect(HoldProgress(elapsed: 2.0, holdSeconds: 2).isComplete)
        #expect(HoldProgress(elapsed: 3.5, holdSeconds: 2).fraction == 1)
    }

    @Test func rewindIsQuickAndScalesWithHowFarItGot() {
        let tiny = HoldProgress(elapsed: 0.05, holdSeconds: 2)
        let most = HoldProgress(elapsed: 1.8, holdSeconds: 2)
        #expect(tiny.rewindSeconds == 0.12)
        #expect(most.rewindSeconds == 0.4)
        #expect(HoldProgress(elapsed: 1.0, holdSeconds: 2).rewindSeconds == 0.25)
    }
}

// MARK: - Practice mode

@MainActor
private final class SpySink: LessonEventSink {
    var events: [LessonFrameEvent] = []
    func lessonFrame(didReport event: LessonFrameEvent) { events.append(event) }
}

@MainActor
struct PracticeModeTests {

    @Test func onboardingFramesRunInPracticeMode() {
        #expect(OnboardingViewModel().frameMode.isPractice)
    }

    @Test func practiceModeReportsNothing() {
        let mode = LessonFrameMode.practice
        // Practice holds no sink, so nothing can reach the engine or SessionEvents.
        for event: LessonFrameEvent in [.next, .again, .done, .moodChosen(.wobbly), .menuOpened] {
            mode.report(event)
        }
        #expect(mode.isPractice)
    }

    @Test func liveModeForwardsEveryEvent() {
        let spy = SpySink()
        let mode = LessonFrameMode.live(spy)
        let events: [LessonFrameEvent] = [.next, .again, .done, .moodChosen(.needsBreak), .menuOpened]
        events.forEach(mode.report)
        #expect(spy.events == events)
    }
}
