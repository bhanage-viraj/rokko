# Adaptive engine (RokkoEngine)

Pure Swift package, no UI imports, fully unit tested. Every number comes from
`Content/EngineConfig.json`.

```
GameScene ──events──▶ LessonViewModel ──▶ BKTModel.update(evidence)
                                         │
                       RoundPlanner ◀────┘  (next skill, type, exercise)
                            │
                       LevelSelector (P(known) → level 1–6)
                            │
                       RoundGenerator (code + seed → RoundSpec)
                            │
LessonViewModel ──RoundSpec──▶ GameScene         HintLadder runs inside the round
```

## 1. Skills
| Skill | Starts | Updated by |
|---|---|---|
| king, queen, rook, bishop, knight, pawn | 0.10 | Types 1, 2, 3, 4 |
| colour | 0.10 | Type 5; black-twin picks at Types 1/2 level 6 |
| teamMakeup | 0.10 | Type 4, once per finished shelf |

Types 1 and 2 share one score per piece.

## 2. BKT
Parameters: `pL0 0.10`, `transit 0.15`, `slip 0.10` (`0.30` when Wobbly), `guess = 1 ÷ choices`.

```
correct:   post = P·(1−S) / (P·(1−S) + (1−P)·G)
incorrect: post = P·S / (P·S + (1−P)·(1−G))
next P     = post + (1 − post)·T
```
Clamp P to [0.001, 0.999].

### Guess value per type
| Type | G |
|---|---|
| 1, 2 | 1 ÷ number of cards |
| 3 | 1 ÷ unlinked pieces left |
| 6 | 1 ÷ empty slots of distinct shapes left |
| 8 | 0.5 |

### Evidence per round (or per drop in drag games)
| What happened | Update |
|---|---|
| Correct, no hint | correct |
| Correct after Hint 1 | correct, with `G = min(0.6, G × hint1GuessMultiplier)` (multiplier 2.0) |
| Correct after Hint 2 | none |
| Hint 3 reached | incorrect |
| Tap/drop faster than `fastTapRatio` (0.40) × child's median response time | none (ignored) |

Median response time = median of the child's first 10 counted responses, then rolling median of the last 20. Until 10 exist, nothing is ignored.

## 3. LevelSelector
| P(known) | Level |
|---|---|
| < 0.30 | 1 |
| 0.30–0.45 | 2 |
| 0.45–0.60 | 3 |
| 0.60–0.75 | 4 |
| 0.75–0.88 | 5 (only if the charcoal intro has played) |
| 0.88–0.95 | 6 (only if colour ≥ 0.50, else stays 5) |
| ≥ 0.95 | mastered → review only |

Rules
- Band edges have a 0.05 buffer: move up only when P ≥ edge + 0.05; move down only when P < edge − 0.05.
- Max one level step per round from the last level played on that exercise.
- Wobbly: level − 1 (min 1) until the next break ends.
- Drag games use: Type 3 → mean of the involved piece skills; Type 4 → teamMakeup; Type 5 → colour.
- Before the first round with anything black in it, the coordinator inserts the black team intro, once (DECISIONS 15 Nov). No level goes above `levels.maxLevel` (1 for now).

## 4. RoundPlanner
Per game block (Module 1, Module 2, Module 3):
- Candidates = unmastered skills of the current module; earlier modules are review.
- Target = lowest P(known); never the same piece twice in a row.
- Types 1 and 2 alternate for the same piece.
- Every `reviewEvery` (4) rounds, one review round on a mastered or earlier-module piece at its current level.
- Module 3 cycles Type 3 → Type 4 → Type 5 (Types 4 and 5 off for now, DECISIONS 15 Nov), white exercise then black, and inserts Type 1/2 review rounds for any piece under 0.95.

Block end
| Block | Ends when | Minimum rounds | Max rounds per sitting |
|---|---|---|---|
| Module 1 | King, Rook, Knight ≥ 0.60 (or 6 rounds played) | 3 | 14 |
| Module 2 | All six pieces ≥ 0.75 (or 6 rounds played) | 3 | 14 |
| Module 3 | All 8 skills ≥ 0.95 (for now the six pieces only: Types 4 and 5 are off, DECISIONS 15 Nov), or 6 rounds played | 3 | 10 |

If the max is reached first, the coordinator offers the Guardian "Stop here for today" (resume in the same block next time) or "Keep going".

Lesson 1 complete = all 8 skills ≥ 0.95. After that, Lesson 1 is practice.

## 5. HintLadder
- States: none → 1 (clue card) → 2 (arrow) → 3 (result, round ends).
- Step up on a wrong answer. The first `hints.freeTries` (1) wrong answers per target get only the soft try-again, no hint.
- Idle hints are off (`hints.idleHints: false`): the Guardian explains the game first, and a timer must never show the answer while they talk. If turned on, a step comes after `idleSeconds` (12; 18 in Calm or Wobbly) with no input, and idle stops at the arrow: only wrong answers reach step 3.
- Input locked while a hint appears (`hints.lockMs`, 1000).
- The ladder resets each round (drag games: each target).

## 6. Mood (Dials)
| Mood | Effect |
|---|---|
| Ready | none |
| Wobbly | slip 0.30, level −1, idle hint 18 s, Calm look and sound; lasts until the next break ends |
| Needs a break | open break picker |

SignalMonitor: 3 wrong answers in the last 4 rounds **and** response time rising above 1.5× median → Guardian button glows softly. The engine never changes mood itself.

## 7. RoundGenerator
Input: exercise code + level + plays. Output: `RoundSpec` (target, options, positions, prefilled slots, batches, voice keys).
- Rounds are not invented: each one is a row of `Content/Lesson1/exercise_pool.json` (from Lesson_1_Exercise_Pool).
- Round picked = pool rounds for that exercise+level, in pool order, index = (times this exercise+level was played) mod (rounds at that level). Levels with one round repeat it.
- The picked round's full code `LLL-M-TT-EE-V-III` is the seed: FNV-1a 64, PRNG = SplitMix64. The seed sets card positions, figure order and batches only; which cards appear comes from the pool.
- Rules per type and level: `docs/EXERCISES.md`, data in `Content/Lesson1/exercises.json`.
- Never place the answer in the same slot as the previous round.

## 8. Storage (SwiftData)
- `ChildProfile` (one), `SkillState(skill, p, attempts, lastPractised)`, `ExerciseState(code-without-variation, lastLevel, plays)`,
  `LessonProgress(stepId, block, roundIndex)`, `Settings(calm, sound)`, `SessionEvent(time, code, skill, outcome, hintLevel, responseMs, mood)`.
- SessionEvent stays on the iPad only. Kept for the summary and the median; trimmed to the last 2,000 events.

## 9. Tests (required)
- BKT maths against hand-computed values.
- Band selection, buffer and max-one-step.
- Evidence rules (hint 1/2/3, fast tap ignored, median warm-up).
- RoundGenerator: every round in the pool produces a valid `RoundSpec`; determinism (same code → same round); answer slot never repeats.
- Planner: never same piece twice; review every 4th; gates open at the right thresholds.
- Content validation: every voice key and asset name referenced in JSON exists; every exercise in `exercises.json` has rounds for levels 1–6 in the pool; every pool round obeys its level rules (option count, look-alikes, twin, pair counts, team of 16).
