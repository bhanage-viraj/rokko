//
//  OnboardingScreen.swift
//  "Screen object" for first-run setup: the tests say *what* to do ("choose Calm"),
//  this file knows *how* to find it on screen. If a button changes, fix it here only.
//

import XCTest

@MainActor
struct OnboardingScreen {
    let app: XCUIApplication

    // MARK: Elements

    /// The big "Next" / "Start Lesson 1" pill on the page steps (welcome, chess, ready).
    var continueButton: XCUIElement { app.buttons["onboarding.continue"] }
    /// The lesson frame's Next, used by the full-screen steps (look, tryGuardian).
    var lessonNextButton: XCUIElement { app.buttons["lesson.next"] }
    var backButton: XCUIElement { app.buttons["Back"] }
    var skipButton: XCUIElement { app.buttons["Skip setup"] }
    /// "About 1 minute", "Step 2 of 4", …
    var progress: XCUIElement { app.descendants(matching: .any)["onboarding.progress"] }

    var welcomeTitle: XCUIElement { app.staticTexts["Learn chess, side by side."] }
    var chessTitle: XCUIElement { app.staticTexts["Do you play chess?"] }
    var lookQuestion: XCUIElement { app.anything(containing: "How do busy screens feel?") }
    var readyTitle: XCUIElement { app.staticTexts["You're ready."] }

    /// "Not yet", "A little", "Yes" (chess) or "Calm", "Standard" (look).
    func option(_ title: String) -> XCUIElement { app.buttons[title] }

    // MARK: Actions

    /// Waits for the launch animation to finish and the welcome page to show.
    @discardableResult
    func waitForWelcome(file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: RokkoUITestCase.screenTimeout),
                      "Welcome page never appeared", file: file, line: line)
        return self
    }

    @discardableResult
    func goToChess() -> Self {
        continueButton.tap()
        XCTAssertTrue(chessTitle.waitForExistence(timeout: 3), "Chess question did not appear")
        return self
    }

    @discardableResult
    func chooseChess(_ answer: String) -> Self {
        option(answer).tap()
        return self
    }

    @discardableResult
    func goToLook() -> Self {
        continueButton.tap()
        XCTAssertTrue(lookQuestion.waitForExistence(timeout: 3), "Look question did not appear")
        return self
    }

    @discardableResult
    func chooseLook(_ answer: String) -> Self {
        option(answer).tap()
        return self
    }

    @discardableResult
    func skipToReady() -> Self {
        skipButton.tap()
        XCTAssertTrue(readyTitle.waitForExistence(timeout: 3), "Ready page did not appear")
        return self
    }

    /// Taps "Start Lesson 1" and returns the lesson map.
    func startLessonOne() -> LessonMapScreen {
        XCTAssertEqual(continueButton.label, "Start Lesson 1")
        continueButton.tap()
        return LessonMapScreen(app: app)
    }
}
