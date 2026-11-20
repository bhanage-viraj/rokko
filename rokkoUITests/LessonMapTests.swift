//
//  LessonMapTests.swift
//  The home screen. Opened directly with `-RokkoScreen lessonMap`, so these tests skip setup.
//

import XCTest

final class LessonMapTests: RokkoUITestCase {

    @MainActor
    func testLessonMapShowsLessonOne() {
        let map = LessonMapScreen(app: launchApp(screen: "lessonMap")).waitUntilShown()

        XCTAssertTrue(map.lessonOneLabel.exists)
        XCTAssertTrue(map.startLessonOne.isHittable, "Start must be on screen and tappable")
        XCTAssertTrue(map.settingsButton.exists, "Guardian settings button")
    }
}
