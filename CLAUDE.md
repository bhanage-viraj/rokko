# Rokko (iPad)

Parent-led iPad app: an autistic child (ASD level 1, age 6–10) and a Guardian learn chess
side by side, next to a real board. This repo is Lesson 1 only.

Read these before writing code, in this order:
1. `docs/PRD.md` – what we build and why
2. `docs/EXERCISES.md` – the games (source of truth: Exercise Types v6)
3. `docs/ENGINE.md` – BKT + level selection + round planner
4. `docs/ARCHITECTURE.md` – modules, folders, data flow
5. `docs/DESIGN_SYSTEM.md` – tokens, layout, motion
6. `docs/ASSETS.md` – every file name the code expects
7. `docs/DECISIONS.md` – what was decided, and what is still open

## Stack
- Swift 6, iPadOS 26+, iPad only, landscape only. Apple frameworks only, no third-party packages.
- SwiftUI app shell and Guardian screens.
- SpriteKit for every game: one persistent `SKView` (via `SpriteView`) for the whole lesson; each game type is an `SKScene`.
- Animal-becomes-piece clips play as `SKVideoNode` inside the game view. The opening film plays in `AVPlayer`.
- MVVM + `LessonCoordinator`. Local Swift packages: `RokkoEngine` (pure Swift, no UI imports), `RokkoContent` (Codable models).
- SwiftData for storage. One child profile per iPad. No iCloud.
- **No network code of any kind. No export of data.** Nothing leaves the iPad.

## Folder layout
```
App/            SwiftUI: RokkoRoot, launch, onboarding, lesson map, LessonContainer, Guardian screens, overlays
Scenes/         SpriteKit: GameHost, LessonScene (base), ChoiceScene, LinkScene, ShelfScene, TeamsScene
Scenes/Nodes/   CardNode, CharacterNode, PieceNode, ClueCardNode, HintArrowNode, SlotNode, BasketNode
Packages/RokkoEngine/   BKTModel, LevelSelector, RoundPlanner, RoundGenerator, HintLadder, SignalMonitor, Dials
Packages/RokkoContent/  Lesson, Step, ExerciseCode, ExerciseRules, Skill, EngineConfig, VoiceLine models
Content/        EngineConfig.json, Lesson1/{lesson1.json, exercises.json, skills.json, voice_lines.csv, manifest.json}
Services/       Store (SwiftData), AudioService, CaptionService, Haptics(off), AccessibilityService
Resources/      Art.xcassets (atlases), Audio/, Video/, Fonts/
Tests/          RokkoEngineTests, RoundGeneratorTests, ContentValidationTests
```

## Product rules (never break)
- Nothing advances on its own: every step waits for the Guardian's tap on Next or Done.
- The frame never moves: top bar, caption bar, question area, answer area, Next (bottom-right), Again (↻ symbol, just left of Next).
- No red, no X, no score, no visible level, no round dots, no music. Celebrations under 1 s.
- Wrong answer = card sinks, dims, lilac dashed outline. Never a buzzer, never "wrong".
- Every child line is a recorded voice file. Captions match it word for word.
- Question pattern is always "Find the <name>." (colour word only at levels 5–6: "Find the white King.").
- Each colour token has one role. Use `RokkoColor` tokens, never raw hex.
- Calm mode and iOS Reduce Motion must work on every screen and scene.
- Mood is set only by the Guardian. The engine may suggest (Guardian button glows), never act.
- Adaptive changes happen only between rounds, one level step at a time.
- No AI at runtime. Child-facing content is identical every time for the same seed.
- No Skip button, no speaker/replay button, no round dots (removed in design).
- Guardian screens say "Guardian's turn".

## Code rules
- Scenes draw and report events (tap, drag start, drop, idle). All decisions live in view models and `RokkoEngine`.
- Every tuning number comes from `Content/EngineConfig.json`. No magic numbers in code.
- Exercise IDs use the v6 code `LLL-M-TT-EE-V-III` everywhere (files, logs, voice keys). See `docs/EXERCISES.md`.
- `RoundGenerator` is deterministic: same code + variation → same round. Seed = FNV-1a hash of the full code.
- Lock input while feedback, hints or clips play.
- Any change to `RokkoEngine` or `RoundGenerator` needs unit tests. Run `ContentValidationTests` after editing any JSON.
- Asset and voice file names follow `docs/ASSETS.md` exactly. A missing asset must fail a test, not crash at runtime.
- Build Lesson 2 later as a new content pack + new scene types registered with the coordinator. Do not special-case Lesson 1 in the engine.

## Commands
- Build: `xcodebuild -scheme Rokko -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' build`
- Test:  `xcodebuild test -scheme Rokko -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)'`
- Engine only (fast): `swift test --package-path Packages/RokkoEngine`

## Don't
- Add analytics, ads, accounts, network calls, export, or third-party SDKs.
- Change copy, voice lines or lesson order without updating `lesson1.json`, `voice_lines.csv` and the captions together.
- Make health, therapy or "clinically proven" claims in any user-facing text.
- Show the child any level, score, percentage or count of rounds.
- Use the words "Amazon", "wrong", "fail" or "mistake" in any child-facing line.
