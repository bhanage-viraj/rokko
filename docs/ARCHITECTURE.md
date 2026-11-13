# Architecture

```
RokkoApp (SwiftUI shell + SpriteKit games · iPadOS 26 · landscape · offline)
├─ RokkoRoot ─ launch animation → onboarding (first run) → lesson map → lesson
├─ LessonContainer (SwiftUI)
│   ├─ LessonCoordinator ─ state machine over lesson1.json steps; owns Next / Again / Done
│   ├─ StoryPlayer        AVPlayer: opening film clips (calm | standard)
│   ├─ GameHost           SpriteView holding ONE SKView for the whole lesson
│   │   ├─ MeetScene       meet the animal + transformation (SKVideoNode) + after state
│   │   ├─ ChoiceScene     Types 1 & 2
│   │   ├─ LinkScene       Type 3
│   │   ├─ ShelfScene      Type 6
│   │   └─ TeamsScene      Type 8
│   ├─ Overlay (SwiftUI)  top bar · caption bar · Next · Again
│   └─ Guardian views     Guardian's turn · break picker / running · mood check · Guardian menu · play together · summary
├─ RokkoEngine (package)  BKTModel · LevelSelector · RoundPlanner · RoundGenerator · HintLadder · SignalMonitor · Dials
├─ RokkoContent (package) Codable models for lesson, exercises, skills, config, voice lines
├─ Services               Store (SwiftData) · AudioService · CaptionService · AccessibilityService
└─ Content + Resources    JSON · art atlases · audio · video · fonts
```

## Why this shape
- **One SKView.** Scenes swap with `presentScene(_:transition:)` inside the same view: no flash, textures stay cached.
- **Meet + transformation in SpriteKit.** The animal-becomes-piece clip runs in an `SKVideoNode`, then the scene swaps the video for the live piece sprite, so Again just replays the node.
- **Engine is pure Swift.** No SpriteKit or SwiftUI imports; everything testable from `swift test`.
- **Lessons are data.** The coordinator only knows step kinds. Lesson 2 = a new content pack + new scene types.

## Step kinds (lesson1.json)
| kind | Shown by | Waits for |
|---|---|---|
| `film` | StoryPlayer | Next |
| `meet` | MeetScene | Next |
| `transform` | MeetScene (SKVideoNode) | Next (Again replays) |
| `guardianShow` | SwiftUI | Done |
| `guardianModule` | SwiftUI | Done |
| `gameBlock` | Choice/Link/Shelf/Teams scenes, chosen per round | block end (ENGINE §4) |
| `charcoalIntro` | MeetScene | Next (inserted by engine, once) |
| `break` | SwiftUI | End break |
| `playTogether` | SwiftUI | We're done |
| `complete` | SwiftUI + scene | Finish |

## Scene ⇄ view model contract
```swift
protocol GameSceneDelegate: AnyObject {
    func scene(_ s: LessonScene, didReport event: InputEvent)   // tap(cardId), dragStart(id), drop(id, targetId), idle
}
protocol LessonScenePresenting {
    func load(_ round: RoundSpec)            // build the round
    func show(_ feedback: Feedback)          // correct(id) | tryAgain(id) | springBack(id) | hint(level, targetId) | result(id)
    func setInputLocked(_ locked: Bool)
    func apply(_ dials: Dials)               // calm, reduceMotion, wobbly
}
```
Scenes never decide correctness. The view model checks the answer against `RoundSpec`, updates BKT, and sends feedback.

## Shared SpriteKit nodes
| Node | Job |
|---|---|
| `CardNode` | rounded card (radius 28), states: idle, pressed, glowFaint, glowStrong, tryAgain, correct, dimmed |
| `CharacterNode` | animal PNG; idle breathe (4 s loop), lift, settle; ivory/charcoal |
| `PieceNode` | piece PNG; ivory/charcoal; reward settle |
| `ClueCardNode` | half-transparent story still with honey edge |
| `HintArrowNode` | honey arrow, 6 pt bob |
| `SlotNode` | silhouette slot (character or piece) for shelf and houses |
| `BasketNode` | Type 8 batch source |
| `LinkLineNode` | line between linked cards (moss, 6 pt, round caps) |
| `LeafEmitter` | SKEmitterNode; off in Calm and Reduce Motion |

## Motion (SKAction)
| Event | Action |
|---|---|
| Card press | scale 0.97, 120 ms |
| Correct | moss ring fade-in + 8 pt bounce, 350 ms |
| Try again | move down 16 pt + alpha 0.6 + lilac dashed outline, 300 ms |
| Drag lift | scale 1.08 + soft shadow; snap within 44 pt, ease-out 220 ms, no bounce |
| Spring back | ease-out 300 ms to origin |
| Scene change | cross-fade 300 ms |
| Reduce Motion / Calm | no bounce, no lift scale, fades only |

## Audio
- `AudioService`: one `AVAudioEngine`; voice and effects on separate player nodes; voice ducks effects.
- Lines are queued by voice key from `voice_lines.csv`; `CaptionService` shows the matching text for exactly as long as the file plays.
- Calm: effects −40% (−4.4 dB).

## Persistence and resume
SwiftData models in ENGINE §8. Save after each step and each round. On launch, resume to the saved step; inside a game block, resume with a fresh round from the planner.

## Guardian controls
- Top-left pause: tap → paused overlay with Resume only.
- Guardian button (top-right): one-finger long press 2 s → mood check; the Guardian menu opens from Settings on the lesson map (Resume, Calm/Standard, sound, Leave lesson). Hold rings fill to show progress.

## Testing
Engine and content unit tests (ENGINE §9). UI is checked by hand on device in Calm and Standard, with Reduce Motion on and off.
