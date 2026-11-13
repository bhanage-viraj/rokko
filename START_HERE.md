# Start here

1. Create a new GitHub repo `rokko-ios` and copy this whole folder into its root.
2. In Xcode 26: New Project → iOS App, name **Rokko**, SwiftUI, Swift 6, iPad only, landscape only, minimum iPadOS 26. Save it into the repo root.
3. Open the repo in Claude Code and paste the prompt below.

## First prompt for Claude Code
```
Read CLAUDE.md, then every file in docs/ in the order CLAUDE.md lists.
Do not write UI yet. Build in this order and stop after each phase for my review:

Phase 1 – Packages/RokkoContent: Codable models for Content/EngineConfig.json and
Content/Lesson1/*.json and voice_lines.csv. ContentValidationTests that load every file,
check every voice id and asset name referenced exists in docs/ASSETS.md naming, and fail clearly.

Phase 2 – Packages/RokkoEngine: BKTModel, LevelSelector, RoundPlanner, RoundGenerator
(FNV-1a 64 seed + SplitMix64), HintLadder, SignalMonitor, Dials, exactly as docs/ENGINE.md
and docs/EXERCISES.md say. Full unit tests from ENGINE.md §9. No UI imports.

Phase 3 – App shell: RokkoRoot (use RokkoLaunchView.swift), onboarding, lesson map,
LessonContainer, LessonCoordinator over lesson1.json, SwiftData store, overlay
(top bar, caption bar, Next, Again), Guardian button holds, pause.

Phase 4 – GameHost with one SKView, shared nodes, ChoiceScene (Types 1–2) with
placeholder art from docs/ASSETS.md names.

Phase 5 – MeetScene with SKVideoNode, LinkScene, ShelfScene, TeamsScene.

Use placeholder rectangles with the asset name printed on them for any missing art, and a still placeholder card for any missing video (videos come later from the video team).
Never invent copy: every child line comes from voice_lines.csv.
```
