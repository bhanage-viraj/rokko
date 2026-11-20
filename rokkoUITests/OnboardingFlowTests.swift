//
//  OnboardingFlowTests.swift
//  First-run setup, driven exactly like a Guardian would: tap, wait, check what's on screen.
//  Every test pattern here is Arrange → Act → Assert.  Guide: docs/UI_TESTING.md
//

import XCTest

final class OnboardingFlowTests: RokkoUITestCase {

    // MARK: Lesson 1 — "does the screen show what I expect?"

    @MainActor
    func testFreshInstallOpensOnWelcome() {
        // Arrange + Act: a brand-new install
        let app = launchApp()
        let setup = OnboardingScreen(app: app).waitForWelcome()

        // Assert
        XCTAssertEqual(setup.progress.label, "About 1 minute")
        XCTAssertFalse(setup.backButton.exists, "There is nothing to go back to on the first page")
        XCTAssertEqual(setup.continueButton.label, "Next")
        attachScreenshot(app, named: "Welcome")
    }

    // MARK: Lesson 2 — state: enabled / disabled / selected

    @MainActor
    func testNextWaitsForAChessAnswer() {
        let setup = OnboardingScreen(app: launchApp()).waitForWelcome().goToChess()

        XCTAssertEqual(setup.progress.label, "Step 1 of 4")
        XCTAssertFalse(setup.continueButton.isEnabled, "Next must wait for an answer")

        setup.chooseChess("Not yet")

        XCTAssertTrue(setup.option("Not yet").isSelected)
        XCTAssertFalse(setup.option("Yes").isSelected)
        XCTAssertTrue(setup.continueButton.isEnabled)
    }

    @MainActor
    func testBackReturnsToWelcome() {
        let setup = OnboardingScreen(app: launchApp()).waitForWelcome().goToChess()

        setup.backButton.tap()

        XCTAssertTrue(setup.welcomeTitle.waitForExistence(timeout: 3))
    }

    @MainActor
    func testSkipNeedsBothAnswers() {
        let setup = OnboardingScreen(app: launchApp()).waitForWelcome().goToChess()

        setup.chooseChess("A little")
        XCTAssertFalse(setup.skipButton.isEnabled, "Skip needs the look answer too")

        setup.goToLook().chooseLook("Calm")
        XCTAssertTrue(setup.skipButton.isEnabled)
    }

    @MainActor
    func testLookNextOpensGuardianPractice() {
        let setup = OnboardingScreen(app: launchApp()).waitForWelcome()
            .goToChess().chooseChess("Not yet")
            .goToLook()

        XCTAssertFalse(setup.lessonNextButton.isEnabled, "Next waits for Calm or Standard")
        setup.chooseLook("Calm")
        setup.lessonNextButton.tap()

        XCTAssertTrue(setup.app.anything(containing: "your turn").waitForExistence(timeout: 3))
        XCTAssertEqual(setup.progress.label, "Step 3 of 4")
    }

    // MARK: Lesson 3 — a whole journey, end to end

    @MainActor
    func testNewFamilyReachesLessonMap() {
        let app = launchApp()
        let setup = OnboardingScreen(app: app).waitForWelcome()
            .goToChess().chooseChess("Not yet")
            .goToLook().chooseLook("Calm")
            .skipToReady()

        // The summary reflects the answers: new to chess → full tips.
        XCTAssertTrue(app.anything(containing: "Calm look").exists)
        XCTAssertTrue(app.anything(containing: "Full tips").exists)
        attachScreenshot(app, named: "Ready")

        setup.startLessonOne().waitUntilShown()
        attachScreenshot(app, named: "Lesson map")
    }

    @MainActor
    func testExperiencedPlayerGetsShortTips() {
        let app = launchApp()
        OnboardingScreen(app: app).waitForWelcome()
            .goToChess().chooseChess("Yes")
            .goToLook().chooseLook("Standard")
            .skipToReady()

        XCTAssertTrue(app.anything(containing: "Standard look").exists)
        XCTAssertTrue(app.anything(containing: "Short tips").exists)
    }

    // MARK: Lesson 4 — jump straight to a step with a launch argument

    @MainActor
    func testCanOpenSetupAtTheLookStep() {
        let setup = OnboardingScreen(app: launchApp(onboardingStep: "look"))

        XCTAssertTrue(setup.lookQuestion.waitForExistence(timeout: Self.screenTimeout))
        XCTAssertEqual(setup.progress.label, "Step 2 of 4")
    }
}
