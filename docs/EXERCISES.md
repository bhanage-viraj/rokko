# Lesson 1 exercises

Sources of truth: **Lesson 1 Exercise Types v6** (the rules) and **Lesson_1_Exercise_Pool** (every round, imported 13 Nov 2026).
This file turns them into a build spec. Lesson 1 uses Types 1–5 as numbered in the pool:
Type 1 (character → piece), Type 2 (piece → character), Type 3 (linking), Type 4 (team shelf), Type 5 (both teams).

## Codes
`LLL-M-TT-EE-V-III` = Lesson · Module · Type · Exercise · Level · pool row

Example: `001-1-01-02-3-052` = Lesson 1, Module 1, Type 1, Exercise 2 (Rook), Level 3, pool row 052 (the 1st of 10 rounds at that level).

III is the row number in the pool (001–690), unique across Lesson 1; it is not reset per level.
Exercise numbers run through the whole module (Module 3: Type 3 = Ex 01–02, Type 4 = Ex 03–04, Type 5 = Ex 05–06).

| Module | Type | Ex | Shown | Choose from | Colour of target |
|---|---|---|---|---|---|
| 1 | 01 | 01 | King character | pieces | white |
| 1 | 01 | 02 | Rook character | pieces | white |
| 1 | 01 | 03 | Knight character | pieces | white |
| 1 | 02 | 04 | King piece | characters | white |
| 1 | 02 | 05 | Rook piece | characters | white |
| 1 | 02 | 06 | Knight piece | characters | white |
| 2 | 01 | 01–03 | Queen, Bishop, Pawn characters | pieces | white |
| 2 | 02 | 04–06 | Queen, Bishop, Pawn pieces | characters | white |
| 3 | 03 | 01 | Link white characters ↔ white pieces | | white |
| 3 | 03 | 02 | Link black characters ↔ black pieces | | black |
| 3 | 04 | 03 | White shelf, character figures | | white |
| 3 | 04 | 04 | Black shelf, piece figures | | black |
| 3 | 05 | 05 | Both teams, characters | | both |
| 3 | 05 | 06 | Both teams, pieces | | both |

## The round pool
Every round is written out in `Content/Lesson1/exercise_pool.json` (690 rounds). The app never invents a round.
- Re-import after the spreadsheet changes: `python3 -I Tools/import_exercise_pool.py <Lesson_1_Exercise_Pool.numbers> rokko/Content/Lesson1/exercise_pool.json`. The importer checks every row and stops on any error.
- Items are written `<colour>.<form>.<piece>`, e.g. `white.character.king`, `black.piece.pawn`, `shaded.character.rook`.
- The pool fixes **which** cards appear. The seed (FNV-1a of the full code) fixes **where** they appear: card positions, figure order, batch order. The pool lists the right answer first; never show that order.
- Which round is played at a level: see `docs/ENGINE.md › RoundGenerator`.

Rounds per level (from the pool; "possible" = how many different rounds the rules allow):

| Type · Ex | L1 | L2 | L3 | L4 | L5 | L6 |
|---|---|---|---|---|---|---|
| 1/2 · King, Rook, Knight, Queen | 6 of 6 | 4 of 4 | 10 of 10 | 1 of 1 | 10 of 110 | 10 of 110 |
| 1/2 · Bishop, Pawn | 3 of 3 | 7 of 7 | 10 of 10 | 1 of 1 | 10 of 110 | 10 of 110 |
| 3 · 01, 02 | 10 of 15 | 1 | 10 of 495 | 10 of 66 | 1 | 1 |
| 4 · 03, 04 | 1 | 1 | 1 | 1 | 1 | 10 of 102 |
| 5 · 05, 06 | 10 of 1600 | 10 of 2809 | 10 of 2916 | 10 of 2401 | 10 of 729 | 1 |

## Shared rules
- **Untaught pieces may appear as wrong options** (Module 1 rounds include Queen, Bishop and Pawn cards).
- **Look-alikes** (from the pool's level 2 rounds): King ↔ Queen, Rook ↔ Pawn, Knight ↔ Bishop, Bishop ↔ Pawn. Stored in `EngineConfig.json › lookAlikes`.
- **Colour words** only appear at levels 5–6: "Find the white King."
- Card positions shuffle by seed. The right answer is never in the same slot twice in a row.
- Celebrations < 1 s; Guardian taps Next after every round.

## Type 1 · Character → piece (tap one card)
Top: the white character (large). Below: N piece cards.
Voice: "Find the King." Correct: the animal says "I'm the King!" and the piece symbol settles on it (`reward_<piece>` action).

| Level | Options | Rule |
|---|---|---|
| 1 | 3 | Same colour (white), no look-alike of the answer |
| 2 | 3 | Same colour, at least one look-alike of the answer |
| 3 | 4 | Same colour, any shapes |
| 4 | 6 | Same colour, all six pieces |
| 5 | 4 | Mixed colours, answer white, black twin of the answer **not** included |
| 6 | 5 | Level 5 + the black twin of the answer (pool note: "5th option = opposite-color trap") |

Layout: levels 1–3, 5–6 one row, cards 200 × 240 pt minimum. Level 4: one row of six, 168 × 210 pt.

## Type 2 · Piece → character
Mirror of Type 1: top shows the white piece; cards are characters. Same 6 levels.
Voice: "Find the lion." Correct: chosen animal says "I'm the King!".

## Hints (all types)
| Step | What the child sees | Voice |
|---|---|---|
| 1 | Half-transparent clue card in a free corner of the stage: the animal's face half and the piece's face half meeting in the middle | What matches, e.g. "Look at this. The elephant has a tower. The Rook is a tower too." (no question after it) |
| 2 | Arrow (honey) bobs 6 pt toward the right answer / right slot | "Look here." + question |
| 3 | Right answer lights up and names itself; the exercise ends with no tap | "This is the King." |

Triggers: a wrong answer or 12 s idle (18 s Calm or Wobbly) moves one step up. In drag games the hint targets the **next unlinked pair / next empty slot**; in Type 3 it targets the pair the child just missed (clue beside the dragged card, arrow on its partner).

## Type 3 · Linking (drag card onto partner)
Characters in a left column, pieces in a right column (levels 1–4), random order. The child drags a character card onto its piece, or a piece onto its character; on a correct drop a gently curved line draws itself between the two cards and stays; the narrator says a cheer that changes each time, then "The elephant is the Rook!" (e.g. "Well done! The elephant is the Rook!") A wrong drop springs back softly.

| Level | Pairs | Rule |
|---|---|---|
| 1 | 4 | One colour (Ex 01 white, Ex 02 black); any 4 of the six, set by the round |
| 2 | 6 | One colour, all six |
| 3 | 8 | Mixed colours, 3–6 of one colour (set by the round) |
| 4 | 10 | Mixed colours, 4–6 of one colour, shown as two parts of 5 pairs |
| 5 | 6 + 6 | White characters left, black right; same-name pairs meet in the middle; white pieces top, black pieces bottom |
| 6 | 6 → 12 | Six characters in a neutral grey-brown shade (colour hidden); each links to **both** its pieces (white top, black bottom); child matches by shape |

## Type 4 · Team shelf
A shelf with one silhouette slot per piece, in one row: King, Queen, Rook, Bishop, Knight, Pawn.
Figures wait below; the child drags each to a matching slot. As each one lands: "One Rook!" At the end: a finish cheer, then "All six pieces are on the shelf!" (e.g. "You did it! All six pieces are on the shelf!")
**Whole team on the piece shelf (16 Nov):** Ex 04 (piece figures) shows the full team of 16, as the pool lists it: two tiers, K Q R R B B N N on top and the 8 Pawns below. Count lines fill per group ("One King!", "Two Rooks!", "Eight Pawns!"); end: "All sixteen pieces are on the shelf!". Which forms get the whole team is `generator.shelfFullTeamForms` in EngineConfig (now `["piece"]`).
**One of each (character shelf):** Ex 03 (character figures) still keeps one figure per piece: a piece the pool lists under "to place" is placed by the child, otherwise it stands prefilled; other-colour figures (level 6) are also cut to one per piece. What the child places there is 3 · 5 · 3 · 6 · 6 · 6 (+ up to 6 other-colour).
Ex 03 white shelf uses character figures. Ex 04 black shelf uses piece silhouettes and piece figures.

| Level | Prefilled | To place |
|---|---|---|
| 1 | King, Queen, 8 Pawns | 6 |
| 2 | 8 Pawns | 8 |
| 3 | 2 Rooks, 2 Bishops, 2 Knights | 10 |
| 4 | 1 Rook, 1 Bishop, 1 Knight | 13 |
| 5 | none | 16 |
| 6 | none | 16 + 6 of the other colour, mix set by the round (spring back if dragged in; they stay off the shelf) |

## Type 5 · Both teams
White king top-left, black king top-right, each with a house of 6 slots in one row (K Q R B N P, one of each; the pool's 16-piece rounds are cut to one per piece the same way as Type 4). Some slots prefilled (which ones is set by the round). Figures arrive from a basket in batches of 4 (2 white + 2 black). The child drags each to its team's house. Correct: a cheer, then "White team!" / "Black team!". End: a finish cheer, then "All the pieces are with their team!"
Ex 05 characters, Ex 06 pieces; same levels.

| Level | To place (white + black) | Rest |
|---|---|---|
| 1 | 4 + 4 | prefilled |
| 2 | 6 + 6 | prefilled |
| 3 | 8 + 8 | prefilled |
| 4 | 10 + 10 | prefilled |
| 5 | 12 + 12 | prefilled |
| 6 | 15 + 15 | none prefilled (kings stay) |

## Skills each type updates
| Type | Updates |
|---|---|
| 1, 2 | The answer's piece skill. At levels 5–6, choosing the black twin also updates Colour (wrong) |
| 3 | Piece skill of each dragged character (one event per first drop) |
| 4 | Piece skill per drop; Team make-up once per finished shelf |
| 5 | Colour per drop (guess 0.5) |
