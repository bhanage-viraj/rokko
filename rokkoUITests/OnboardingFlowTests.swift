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
    func testNextWaitsForALookAnswer() {
        let setup = OnboardingScreen(app: launchApp()).waitForWelcome().goToLook()

        XCTAssertEqual(setup.progress.label, "Step 1 of 3")
        XCTAssertFalse(setup.lessonNextButton.isEnabled, "Next waits for Calm or Standard")
        XCTAssertFalse(setup.skipButton.isEnabled, "Skip needs the look answer")

        setup.chooseLook("Calm")

        XCTAssertTrue(setup.option("Calm").isSelected)
        XCTAssertTrue(setup.skipButton.isEnabled)
    }

    @MainActor
    func testBackReturnsToWelcome() {
        let setup = OnboardingScreen(app: launchApp()).waitForWelcome().goToLook()

        setup.backButton.tap()

        XCTAssertTrue(setup.welcomeTitle.waitForExistence(timeout: 3))
    }

    @MainActor
    func testLookNextOpensGuardianPractice() {
        let setup = OnboardingScreen(app: launchApp()).waitForWelcome().goToLook()

        setup.chooseLook("Calm")
        setup.lessonNextButton.tap()

        XCTAssertTrue(setup.app.anything(containing: "your turn").waitForExistence(timeout: 3))
        XCTAssertEqual(setup.progress.label, "Step 2 of 3")
    }

    // MARK: Lesson 3 — a whole journey, end to end

    @MainActor
    func testNewFamilyReachesLessonMap() {
        let app = launchApp()
        let setup = OnboardingScreen(app: app).waitForWelcome()
            .goToLook().chooseLook("Calm")
            .skipToReady()

        // The summary reflects the answer.
        XCTAssertTrue(app.anything(containing: "Calm look").exists)
        attachScreenshot(app, named: "Ready")

        setup.startLessonOne().waitUntilShown()
        attachScreenshot(app, named: "Lesson map")
    }

    @MainActor
    func testStandardLookShowsInTheSummary() {
        let app = launchApp()
        OnboardingScreen(app: app).waitForWelcome()
            .goToLook().chooseLook("Standard")
            .skipToReady()

        XCTAssertTrue(app.anything(containing: "Standard look").exists)
    }

    // MARK: Lesson 4 — jump straight to a step with a launch argument

    @MainActor
    func testCanOpenSetupAtTheLookStep() {
        let setup = OnboardingScreen(app: launchApp(onboardingStep: "look"))

        XCTAssertTrue(setup.lookQuestion.waitForExistence(timeout: Self.screenTimeout))
        XCTAssertEqual(setup.progress.label, "Step 1 of 3")
    }
}
