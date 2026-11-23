//
//  LessonClipFlowTests.swift
//  The lesson's videos on the real screen: a transformation and a film clip play, lock Next while
//  they run, then wait for the Guardian (nothing advances by itself), and Again replays them.
//  Screenshots go into the report (fresh install = Calm, the default look).
//

import XCTest

final class LessonClipFlowTests: RokkoUITestCase {

    private func nextButton(_ app: XCUIApplication) -> XCUIElement { app.buttons["lesson.next"] }
    private func againButton(_ app: XCUIApplication) -> XCUIElement { app.buttons["Again"] }

    /// Waits for Next to light up: the clip has ended.
    private func waitForNext(_ app: XCUIApplication, timeout: TimeInterval) {
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: nextButton(app))
        wait(for: [enabled], timeout: timeout)
    }

    @MainActor
    func testTransformationPlaysThenWaitsForNext() {
        let app = launchApp(screen: "lesson", lessonStep: "transform_king")
        XCTAssertTrue(nextButton(app).waitForExistence(timeout: Self.screenTimeout))

        // Playing: Next locked, no Again.
        XCTAssertFalse(nextButton(app).isEnabled, "Next must wait for the clip")
        XCTAssertFalse(againButton(app).exists)
        attachScreenshot(app, named: "Transform – playing")

        // The end: the "after" picture with its name tags; Next and Again on.
        waitForNext(app, timeout: 10)
        XCTAssertTrue(againButton(app).exists)
        XCTAssertTrue(app.anything(containing: "King").waitForExistence(timeout: 2))
        attachScreenshot(app, named: "Transform – after")

        // Nothing moves on by itself.
        sleep(3)
        XCTAssertTrue(app.anything(containing: "King").exists)

        // Again: the clip replays and Next locks again.
        againButton(app).tap()
        XCTAssertFalse(nextButton(app).isEnabled)
        attachScreenshot(app, named: "Transform – again")
        waitForNext(app, timeout: 10)
    }

    @MainActor
    func testFilmClipPlaysToFinishedAndWaits() {
        // Kangaroos: the shortest film clip (14.3 s).
        let app = launchApp(screen: "lesson", lessonStep: "film_05_kangaroos")
        XCTAssertTrue(nextButton(app).waitForExistence(timeout: Self.screenTimeout))
        XCTAssertFalse(nextButton(app).isEnabled, "Next must wait for the film")
        sleep(4)
        attachScreenshot(app, named: "Film – playing")

        waitForNext(app, timeout: 25)
        XCTAssertTrue(app.anything(containing: "Finished").waitForExistence(timeout: 2))
        XCTAssertTrue(againButton(app).exists)
        attachScreenshot(app, named: "Film – finished")

        sleep(3)
        XCTAssertTrue(app.anything(containing: "Finished").exists, "the film step moved on by itself")

        againButton(app).tap()
        XCTAssertFalse(nextButton(app).isEnabled)
        XCTAssertFalse(app.anything(containing: "Finished").exists)
        sleep(2)
        attachScreenshot(app, named: "Film – again")
    }
}
