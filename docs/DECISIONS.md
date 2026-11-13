# Decisions

## Decided (12 Nov 2026)
**Scope**
- Lesson 1 only, no deadline. Exercise Types v6 is the only source for the games, white and black.
- Lesson 1 games: Module 1 (Types 1, 2 · King, Rook, Knight), Module 2 (Types 1, 2 · Queen, Bishop, Pawn), Module 3 (Types 3, 6, 8). Types 4, 5, 7 are not in Lesson 1.
- Story splits: meet King, Rook, Knight → Module 1 → meet Queen, Bishop, Pawn → Module 2 → Module 3.
- The charcoal team is introduced in a short scene before the first level-5 round.
- Lesson 1 runs over several sittings and resumes where it stopped.

**Games**
- Untaught pieces may appear as wrong options.
- Level 5 = 4 mixed-colour options without the black twin; level 6 adds the black twin.
- The target is always white in Modules 1–2.
- "I'm the King!" plays after the correct tap. Each animal has its own reward motion.
- Hint 1 = half-transparent story still; Hint 3 shows the answer and ends the exercise with no tap and counts as not known.
- Hints step up on a wrong answer or idle 12 s (18 s Calm/Wobbly). Drag hints go to the next unlinked pair / empty slot.
- Linking: drag the card onto its partner; the line draws itself. 10-pair level split into two parts. Level 6 shade is neutral grey-brown.
- Black shelf uses piece shapes. Wrong-colour figures spring back. Counts spoken as each group fills. Pawns in two rows of 4.
- Type 8: figures come from a basket in batches; houses are 2 × 8 grids.
- Codes `LLL-M-TT-EE-V-III` are the real IDs; Id = variation.

**Engine**
- BKT stays. One score per piece shared by Types 1 and 2; plus Colour and Team make-up skills.
- Hint 2 correct = no update. Fast-tap guard 40% of the child's median.
- Gates 0.60 / 0.75. Lesson complete when all skills ≥ 0.95.
- Wobbly = one level lower + slower hints. Parents see words only.

**Tech**
- Claude Code builds; you review. GitHub repo.
- iPadOS 26+, landscape, iPad only, one child per iPad, no iCloud.
- SwiftUI shell; SpriteKit for all games (one SKView); transformation clips as SKVideoNode.
- Rounds generated from v6 rules with fixed seeds. Clue cards from story stills. PNG + SKAction motion.
- Guardian controls: long press the Guardian button 2 s for the mood check; settings in the Guardian menu. No data export at all.
- English, strings table ready for more languages. No app size limit.
- You generate the voice lines from the CSV.
- Unit tests for engine and generator (no learner simulator).
- Lesson 2 plugs in as a content pack + new scene types.

**Video**
- All video (opening film, transformation clips, charcoal intro) is made by the video team. The app only plays the files named in `manifest.json`.

**Design kept from the canvas**
- No round dots, no Skip, no speaker/replay button. "Guardian's turn". Again is a ↻ symbol just left of Next (decided 12 Nov; was above Next).
- Mood check moved from Pip to the Guardian button (one-finger long press, 2 s; the two-finger hold didn't work reliably).

**First-run setup (12 Nov 2026)**
- The three setup screens (Before you start, Calm or Standard, Get your pieces ready) are replaced by one guided first-run setup: `docs/ONBOARDING.md`.
- The Guardian learns by doing: a Guardian's turn and the long-press check-in are practised on the real lesson frame, in practice mode (nothing reaches the engine or storage).
- "Do you play chess?" sets the tips: Not yet → full steps on every Guardian's turn; A little / Yes → one line with "Show steps ›".
- No favourite-animal / badge step: it would not change anything in the lesson.
- Next is the main button from the first setup screen, so there is no separate "tap Next" lesson.
- Practice steps move on by themselves once done (no Continue on full-screen steps); the look options are named Calm / Standard.
- No pieces step in setup (too long): the lesson shows the pieces checklist once before the first Guardian's turn.
- iPad orientation lock needs `UIRequiresFullScreen`; set so the app stays landscape.

## Superseded in the old PRD (8 Nov)
FR-14 Skip · FR-22 round dots · FR-11 replay button · FR-24 hold on Pip · 2/3/4-card BKT bands · "Types 3–8 later" · old colour tokens · scheme name ChessJungle · two-week TestFlight date.

## Open (need your answer)
| # | Question | Current assumption in the files |
|---|---|---|
| O1 | Bishop: fox or owl? | fox |
| O2 | Squirrel voice | none; its reward line is blocked |
| O3 | Look-alikes for Rook and Knight at level 2 | Rook→King, Knight→Bishop (ask the chess coach) |
| O4 | Final character heights | elephant 1.10, lion 1.00, horse 0.95, lioness 0.92, fox 0.70, squirrel 0.40 |
| O5 | Words for the teams to the child | "white" and "black" (story names Ivory Hollow / Charcoal Ridge stay in the film) |
| O6 | Guardian controls | pause = tap (Resume only); Guardian button: one-finger long press 2 s = mood; menu from lesson-map Settings (decided 12 Nov) |
| O7 | Level 4 choice cards are 168 × 210 pt (below the 200 × 240 minimum) | allowed as an exception |
| O8 | Module Guardian's turn content | hold up the module's pieces; child points to each and names the animal |
| O9 | Max rounds per sitting | 14 / 14 / 10, then "Stop here for today" or "Keep going" |
| O10 | One voice model for the whole app | eleven_multilingual_v2 (as the film) |
| O11 | Type 3 levels 5–6 layout | as written in EXERCISES.md, needs your sketch to confirm |
| O12 | Commercial licence for final Recraft art | paid plan before final art |
