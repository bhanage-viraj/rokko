//
//  rokkoUITests.swift
//  Launch tests: the castling animation and how long a cold launch takes.
//

import XCTest

final class rokkoUITests: RokkoUITestCase {

    @MainActor
    func testLaunchAnimationLeadsToSetup() {
        let app = launchApp()

        // The launch view is one accessibility element labelled "Rokko".
        XCTAssertTrue(app.descendants(matching: .any)["Rokko"].waitForExistence(timeout: 3))
        // …and when it ends, a fresh install lands on setup.
        OnboardingScreen(app: app).waitForWelcome()
    }

    @MainActor
    func testTapSkipsLaunchAnimation() {
        let app = launchApp()
        let launch = app.descendants(matching: .any)["Rokko"]
        XCTAssertTrue(launch.waitForExistence(timeout: 3))

        launch.tap()   // tap anywhere = skip to the logo

        // Skipping is quicker than the full ~3.3 s story.
        XCTAssertTrue(OnboardingScreen(app: app).welcomeTitle.waitForExistence(timeout: 2.5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
