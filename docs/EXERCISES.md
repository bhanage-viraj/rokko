# Lesson 1 exercises

Source of truth: **Lesson 1 Exercise Types v6**. This file turns it into a build spec.
Only Types 1, 2, 3, 6 and 8 are in Lesson 1. Types 4, 5 and 7 are not.

## Codes
`LLL-M-TT-EE-V-III` = Lesson · Module · Type · Exercise · Level · Id (variation)

Example: `001-1-01-02-3-004` = Lesson 1, Module 1, Type 1, Exercise 2 (Rook), Level 3, variation 4.

Exercise numbers run through the whole module (Module 3: Type 3 = Ex 01–02, Type 6 = Ex 03–04, Type 8 = Ex 05–06).
The variation picks which wrong options appear and their order. Same code = same round, always.

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
| 3 | 06 | 03 | White shelf, character slots | | white |
| 3 | 06 | 04 | Black shelf, piece slots | | black |
| 3 | 08 | 05 | Both teams, characters | | both |
| 3 | 08 | 06 | Both teams, pieces | | both |

## Shared rules
- **Untaught pieces may appear as wrong options** (v6 implies it: Level 1 example is ♛ vs ♟ in Module 1).
- **Look-alikes** (for level 2): King↔Queen, Bishop↔Pawn (from v6). Rook→King, Knight→Bishop are placeholders. Set in `EngineConfig.json › lookAlikes`; confirm with the chess coach.
- **Colour words** only appear at levels 5–6: "Find the white King."
- Card positions shuffle by seed. The right answer is never in the same slot twice in a row.
- Celebrations < 1 s; Guardian taps Next after every round.

## Type 1 · Character → piece (tap one card)
Top: the white character (large). Below: N piece cards.
Voice: "Find the King." Correct: the animal says "I'm the King!" and the piece symbol settles on it (`reward_<piece>` action).

| Level | Options | Rule |
|---|---|---|
| 1 | 3 | Same colour (white), all very different shapes (no look-alike pairs) |
| 2 | 3 | Same colour, includes the answer's look-alike |
| 3 | 4 | Same colour, any shapes |
| 4 | 6 | Same colour, all six pieces |
| 5 | 4 | Mixed colours, answer white, black twin of the answer **not** included |
| 6 | 5 | Level 5 + the black twin of the answer |

Layout: levels 1–3, 5–6 one row, cards 200 × 240 pt minimum. Level 4: one row of six, 168 × 210 pt.

## Type 2 · Piece → character
Mirror of Type 1: top shows the white piece; cards are characters. Same 6 levels.
Voice: "Find the lion." Correct: chosen animal says "I'm the King!".

## Hints (all types)
| Step | What the child sees | Voice |
|---|---|---|
| 1 | Half-transparent clue card next to the target: still from that animal's story moment (`clue_<piece>_<colour>`) | "Let's look again." + question |
| 2 | Arrow (honey) bobs 6 pt toward the right answer / right slot | "Look here." + question |
| 3 | Right answer lights up and names itself; the exercise ends with no tap | "This is the King." |

Triggers: a wrong answer or 12 s idle (18 s Calm or Wobbly) moves one step up. In drag games the hint targets the **next unlinked pair / next empty slot**.

## Type 3 · Linking (drag card onto partner)
Characters on one side, pieces on the other, random order. The child drags a character card onto its piece; on a correct drop the line draws itself and stays; the narrator says "The elephant is the Rook." A wrong drop springs back softly.

| Level | Pairs | Rule |
|---|---|---|
| 1 | 4 | One colour (Ex 01 white: Knight, Rook, Bishop, Pawn · Ex 02 black: King, Queen, Bishop, Knight) |
| 2 | 6 | One colour, all six |
| 3 | 8 | Mixed colours (6 of one + 2 of the other) |
| 4 | 10 | Mixed colours, shown as two parts of 5 pairs |
| 5 | 6 + 6 | White characters left, black right; same-name pairs meet in the middle; white pieces top, black pieces bottom |
| 6 | 6 + 6 | Characters in a neutral grey-brown shade (colour hidden); white pieces top, black bottom; child matches by shape |

## Type 6 · Team shelf
A shelf with silhouette slots: 1 King, 1 Queen, 2 Rooks, 2 Bishops, 2 Knights, 8 Pawns (pawns in two rows of 4).
Figures wait below; the child drags each to a matching slot. As each group fills: "Two Rooks!" At the end: "Sixteen! The whole team is home."
Ex 03 white shelf uses character silhouettes. Ex 04 black shelf uses piece silhouettes and piece figures.

| Level | Prefilled | To place |
|---|---|---|
| 1 | King, Queen, 8 Pawns | 6 |
| 2 | 8 Pawns | 8 |
| 3 | 2 Rooks, 2 Bishops, 2 Knights | 10 |
| 4 | 1 Rook, 1 Bishop, 1 Knight | 13 |
| 5 | none | 16 |
| 6 | none | 16 + 6 of the other colour (spring back if dragged in) |

## Type 8 · Both teams
White king top-left, black king top-right, each with a house of 2 × 8 slots (back row + pawn row). Some slots prefilled. Figures arrive from a basket in batches of 4 (2 white + 2 black). The child drags each to its team's house. Correct: "White team!" / "Black team!". End: "Both teams are home."
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
| 6 | Piece skill per drop; Team make-up once per finished shelf |
| 8 | Colour per drop (guess 0.5) |
