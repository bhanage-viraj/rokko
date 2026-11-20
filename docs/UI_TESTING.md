# UI testing in Rokko — a hands-on guide

You already have **unit tests** (`rokkoTests/`, `Packages/*/Tests`). They call Swift code directly:
"give `RoundController` this tap, check its state". Fast, precise, no screen.

**UI tests** (`rokkoUITests/`) do what a Guardian does: launch the real app, look at the screen, tap.
They catch what unit tests can't — a button hidden behind an overlay, Next not enabling, a screen
that never appears, two steps wired in the wrong order.

| | Unit test | UI test |
|---|---|---|
| Runs | inside the app process | in a **separate** process that remote-controls the app |
| Sees | your types and properties | only the **accessibility tree** (what VoiceOver sees) |
| Speed | milliseconds | seconds per test |
| Use for | logic, engine, content | journeys through screens |

Rule of thumb: many unit tests, a few UI tests for the journeys that matter most.

---

## 1. How XCUITest sees your app

The test can't read `model.step`. It only sees elements: **type** (button, staticText, image…),
**label** (what VoiceOver reads), **identifier** (a hidden name for tests), and state
(`exists`, `isEnabled`, `isSelected`, `isHittable`).

Try it: put a breakpoint in any test after launch and type in the debug console:

```
po app.debugDescription
```

You'll get the whole tree. Xcode's **Accessibility Inspector** (Xcode ▸ Open Developer Tool) shows
the same for any element you point at. This is the #1 debugging tool for UI tests.

Good news: because Rokko already labels things for VoiceOver ("Back", "Skip setup", "Settings"),
it's already easy to test. Accessibility work and testability are the same work.

## 2. Finding elements (queries)

```swift
app.buttons["Skip setup"]                    // button whose label OR identifier is "Skip setup"
app.staticTexts["Do you play chess?"]        // a Text
app.buttons["onboarding.continue"]           // by accessibilityIdentifier
app.descendants(matching: .any)["Rokko"]     // any type
app.anything(containing: "Short tips")       // our helper: label CONTAINS (Support/RokkoUITestCase.swift)
```

**Labels vs identifiers.** Labels are user-facing and can change (copy edits, localisation).
Identifiers never show to anyone, so they're stable. Rokko uses identifiers where two buttons
share a label — both the setup pill and the lesson frame's button say "Next":

| Identifier | Where |
|---|---|
| `onboarding.continue` | Setup's Next / Start Lesson 1 pill (`OnboardingParts.swift`) |
| `onboarding.progress` | "Step 2 of 4" text (`OnboardingParts.swift`) |
| `lesson.next`, `lesson.done` | Lesson frame's Next/Done (`LessonFrame.swift`) |
| `lessonMap.start.<n>` | Start on a lesson card (`LessonMapView.swift`) |

Add one with `.accessibilityIdentifier("area.thing")` when you need it.

## 3. Waiting — the most important habit

The app animates (launch castling, screen fades). A query checked too early fails.

```swift
XCTAssertTrue(element.waitForExistence(timeout: 3))   // ✅ waits up to 3 s
XCTAssertTrue(element.exists)                         // ⚠️ checks right now
sleep(3)                                              // ❌ slow and still flaky
```

Use `waitForExistence` whenever something new should appear. XCUITest already waits for the app
to be idle before each tap, so you don't need waits before tapping things already on screen.

## 4. Controlling the starting state

Every test must start from a known state, or tests break each other. Rokko does this with
launch arguments (read through `UserDefaults`, DEBUG builds only):

| Argument | Effect |
|---|---|
| `-RokkoUITesting YES` | SwiftData in memory: every launch is a fresh install (`rokkoApp.swift`) |
| `-RokkoScreen lessonMap` | Skip straight to the lesson map (`RokkoRoot.swift`) |
| `-RokkoOnboardingStep look` | Open setup at that step |

`launchApp(screen:onboardingStep:)` in `Support/RokkoUITestCase.swift` sets these for you.
Without `-RokkoUITesting`, the first test that finishes setup would make every later test open on
the lesson map instead of Welcome.

## 5. Screen objects — keeping tests readable

Tests describe *what* happens; screen objects (`rokkoUITests/Screens/`) know *how* to find things:

```swift
OnboardingScreen(app: app).waitForWelcome()
    .goToChess().chooseChess("Not yet")
    .goToLook().chooseLook("Calm")
    .skipToReady()
    .startLessonOne()
    .waitUntilShown()
```

If the Skip button is ever renamed, you fix one line in `OnboardingScreen.swift`, not twenty tests.

## 6. Shape of a test: Arrange → Act → Assert

```swift
@MainActor
func testNextWaitsForAChessAnswer() {
    let setup = OnboardingScreen(app: launchApp()).waitForWelcome().goToChess()  // Arrange
    XCTAssertFalse(setup.continueButton.isEnabled)

    setup.chooseChess("Not yet")                                                 // Act

    XCTAssertTrue(setup.option("Not yet").isSelected)                            // Assert
    XCTAssertTrue(setup.continueButton.isEnabled)
}
```

One behaviour per test, and a name that says it (`testSkipNeedsBothAnswers`). When it fails,
the name alone tells you what broke.

## 7. Running them

- **All tests:** ⌘U.
- **One test or class:** click the ◇ diamond next to it in the editor or Test navigator (⌘6).
- **Only UI tests from Terminal:**
  ```
  xcodebuild test -scheme Rokko \
    -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' \
    -only-testing:rokkoUITests
  ```
- **Results:** Report navigator (⌘9) → pick the run. Failed tests show a screenshot at the point of
  failure; tests calling `attachScreenshot` keep theirs too.

## 8. When a test fails

1. Read the message and look at the failure screenshot in the report.
2. "Element not found" → `po app.debugDescription`; the label is often slightly different
   (curly apostrophe, extra words combined in by `.accessibilityElement(children: .combine)`).
3. Works sometimes, fails sometimes → a missing `waitForExistence`.
4. Element exists but tap does nothing → something covers it; check `isHittable`.

## 9. What's covered now

| File | Tests |
|---|---|
| `rokkoUITests.swift` | launch animation → setup; tap skips the animation; launch time |
| `OnboardingFlowTests.swift` | welcome state; Next waits for an answer; Back; Skip needs both answers; look → Guardian practice; two full journeys to the lesson map with the right summary; opening at a step |
| `LessonMapTests.swift` | lesson map shows Lesson 1, Start and Settings |

## 10. Practice exercises (do these yourself)

1. **Easy.** In `LessonMapTests`, tap Settings and assert the Guardian menu appears. Use
   `po app.debugDescription` to find what to look for.
2. **Medium.** Write `testBackFromLookKeepsChessAnswer`: answer chess, go to look, tap Back,
   assert your chess option is still selected.
3. **Medium.** Try Xcode's recorder: put the cursor inside an empty test, click the red ● Record
   button at the bottom of the editor, use the Simulator, stop. Then tidy the generated code into
   screen-object calls — recorded code works but is brittle.
4. **Harder.** Test the check-in step: `launchApp(onboardingStep: "tryCheckIn")`, then a long press
   (`element.press(forDuration: 1.0)`) on the mood control, pick a mood, and wait for setup to move on
   by itself to the ready page (it auto-advances after ~2.6 s, so use a timeout of 5).
5. **Rokko rule check.** Write a test that walks setup and asserts no visible text contains
   "wrong", "fail" or "mistake" (`app.anything(containing:)`, `XCTAssertFalse(... .exists)`).

Note: the games run in SpriteKit, whose nodes are invisible to XCUITest unless you give them
accessibility elements. Game logic is better tested the way `RoundControllerTests` already does it.
