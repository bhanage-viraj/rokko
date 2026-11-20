//
//  LessonMapScreen.swift
//  Screen object for the lesson map (home screen after setup).
//

import XCTest

@MainActor
struct LessonMapScreen {
    let app: XCUIApplication

    var lessonOneLabel: XCUIElement { app.staticTexts["LESSON 1"] }
    var startLessonOne: XCUIElement { app.buttons["lessonMap.start.1"] }
    var settingsButton: XCUIElement { app.buttons["Settings"] }

    @discardableResult
    func waitUntilShown(file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(startLessonOne.waitForExistence(timeout: RokkoUITestCase.screenTimeout),
                      "Lesson map never appeared", file: file, line: line)
        return self
    }
}
