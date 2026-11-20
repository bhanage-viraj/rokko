//
//  RokkoUITestCase.swift
//  Base class for every Rokko UI test: launches the app the same way each time.
//  Guide: docs/UI_TESTING.md
//

import XCTest

class RokkoUITestCase: XCTestCase {

    /// The launch animation runs ~3.3 s, then fades. Give screens this long to appear.
    static let screenTimeout: TimeInterval = 10

    override func setUpWithError() throws {
        // Stop a test at its first failure: later steps would only fail in confusing ways.
        continueAfterFailure = false
    }

    /// Launches Rokko with a fresh, in-memory database (like a brand-new install).
    /// - Parameters:
    ///   - screen: `"lessonMap"` or `"lesson"` to jump straight there (DEBUG launch argument).
    ///   - onboardingStep: an `OnboardingViewModel.Step` name, e.g. `"look"`, to open setup at that step.
    @MainActor
    @discardableResult
    func launchApp(screen: String? = nil, onboardingStep: String? = nil) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft   // Rokko is landscape only
        let app = XCUIApplication()
        // "-Key Value" pairs land in UserDefaults inside the app (see rokkoApp.isUITesting).
        app.launchArguments += ["-RokkoUITesting", "YES"]
        if let screen { app.launchArguments += ["-RokkoScreen", screen] }
        if let onboardingStep { app.launchArguments += ["-RokkoOnboardingStep", onboardingStep] }
        app.launch()
        return app
    }

    /// Saves a screenshot into the test report (Report navigator → the test → Attachments).
    @MainActor
    func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

extension XCUIElement {
    /// Any element (button, text, image…) whose label contains `text`.
    func anything(containing text: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }
}
