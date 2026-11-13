# PRD · Rokko · Lesson 1

Version 2 · 12 Nov 2026 · owner: Viraj Bhanage
Replaces "PRD: Chess App for Autistic Kids and Parents (Lesson 1 MVP)", 8 Nov 2026.

## 1. Overview
Rokko is an iPad app where a Guardian and an autistic child (level 1, age 6–10) learn chess
together, side by side at a real board, with no tutor.

**Name.** Rokko comes from castling: the king and rook move together in one move, written
O-O. The logo's two circles are the two pieces (and the Guardian and child) moving together.

**Problem.** Parents of autistic children want calm, meaningful time together that also
teaches a real skill. Autism-trained chess tutors are expensive or not nearby, most parents
don't play chess, and chess apps are fast, loud and played alone.

**Solution.** A story-led lesson: six animals become the six chess pieces; short games that
adapt to the child; then play together at the real board. The Guardian leads every step.

**Principles.** Predictable screens, one thing at a time, no red or failure signals, calm
senses, nothing advances without the Guardian, all data stays on the iPad.

**Scope of this document.** Lesson 1 only, made as good as possible. No deadline.

## 2. Goals and non-goals
Goals
1. A family completes Lesson 1 at home without outside help.
2. The child links each of the six pieces to its animal and name, in white and black.
3. The child knows a team has 16 pieces (1 · 1 · 2 · 2 · 2 · 8) and tells the two teams apart.
4. Sessions stay calm: the app adapts before the child is overwhelmed.

Non-goals: therapy or clinical claims; solo play; full games of chess; Android or iPhone;
accounts, sync, export or analytics; stickers, scores or leaderboards; music.

## 3. Success measures
No data leaves the iPad, so we measure by sitting with families and asking parents.

| Measure | Target |
|---|---|
| Families who finish Lesson 1 (all skills at 0.95) | 70% |
| Child names 5 of 6 real pieces at the board (parent report) | 70% of children |
| Sessions ended early by distress (parent report) | under 20% |
| Parents who needed no outside help | 80% |

## 4. Users
| User | Who | Needs | What Rokko gives |
|---|---|---|---|
| Child | Autistic (level 1), 6–10, verbal or non-verbal | Predictable structure, literal language, low sensory load, early success | Fixed cast, voiced lines, one question pattern, help that fades, no failure signals |
| Guardian | Often doesn't play chess | Clear instructions, control of pace and mood | Guardian's turn screens, Next, mood check, breaks, summary |

Not for: children playing alone, higher support needs, children who already play well.

## 5. Lesson 1 structure
Lesson 1 runs over several sittings. Leaving saves the exact step; the next sitting resumes there.
Full step list: `Content/Lesson1/lesson1.json`. Games: `docs/EXERCISES.md`.

**Setup (first launch, Guardian):** Launch animation → first-run setup (welcome, chess
experience, look, two hands-on practice steps, ready) → Lesson map. Spec: `docs/ONBOARDING.md`.

**Lesson 1 path**
1. **Opening film** (L1_OP01–OP07): Sixty-Four Wood, Ivory Hollow and Charcoal Ridge, Pip's scroll, the one rule.
2. **Meet King, Rook, Knight**: for each: meet the animal → animal becomes piece (clip) → Guardian's turn (show the real piece).
3. **Module 1 games**: Types 1 and 2 for King, Rook, Knight. Adaptive.
   Charcoal intro (CH01) plays once, just before the first round at level 5.
4. **Guardian's turn: Module 1** (hold up the three pieces, child points to each).
5. **Planned break**.
6. **Meet Queen, Bishop, Pawn**: same three-part pattern.
7. **Module 2 games**: Types 1 and 2 for Queen, Bishop, Pawn, with review rounds of Module 1 pieces.
8. **Guardian's turn: Module 2**.
9. **Module 3 games**: Type 3 (linking), Type 6 (team shelf), Type 8 (both teams), white and black.
10. **Play together** at the real board.
11. **Lesson complete** + Guardian summary in words.

**Module gates** (see ENGINE.md): Module 2 opens when King, Rook, Knight reach 0.60.
Module 3 opens when all six pieces reach 0.75. Lesson 1 is complete when all six pieces,
Colour and Team make-up reach 0.95. If a sitting ends before a gate, the next sitting
resumes in the same game block.

**Any time:** long press (2 s, one finger) on the Guardian button → mood check (Ready / Wobbly /
Needs a break). Guardian menu (Calm/Standard, sound, tips,
Run setup again) from Settings on the lesson map.

## 6. Functional requirements
All are required for Lesson 1 unless marked Later.

### Setup
- FR-01 Launch animation: king and rook castle into the Rokko logo, under 4 s, tap to skip; Calm/Reduce Motion = logo fade.
- FR-02 First-run setup, shown once (`docs/ONBOARDING.md`): welcome → chess experience (sets full or short Guardian's-turn tips) → look (Calm/Standard) → try a Guardian's turn → try the long-press check-in → ready. Pieces checklist moves into the lesson, once, before the first Guardian's turn. Back and Skip on every step except ready; Continue waits for each step's action.
- FR-03 The practice steps use the real lesson frame in practice mode: no engine, no BKT, no SessionEvents, no progress saved.
- FR-04 Saved: Calm, tips mode, setup done. Changeable in the Guardian menu, which also offers "Run setup again".
- FR-05 Lesson map: Lesson 1 active; Lessons 2–3 shown as "Coming soon".

### Lesson frame
- FR-06 Same frame on every lesson screen: top bar (pause left, lesson path centre, Guardian button right), caption bar, Next bottom-right, Again (↻) just left of Next where a clip can be replayed.
- FR-07 Nothing advances on its own; every step waits for Next or Done.
- FR-08 Save after every step and every round; resume exactly there.
- FR-09 Pause (top-left tap) freezes everything and shows Resume only. Settings live in the Guardian menu (lesson map › Settings).

### Story
- FR-10 Opening film plays in the family's chosen version (Calm or Standard); first clip starts only on the Guardian's tap.
- FR-11 Captions match the voice word for word. No replay button; Again replays a transformation clip.
- FR-12 Each piece: meet the animal → becomes piece (clip, then "after" state with Again) → Guardian's turn.
- FR-13 Charcoal intro: one short scene showing the charcoal team as the same animals, before the first level-5 round.

### Guardian's turn
- FR-14 Show the real piece: three steps on first visit, one line after ("Show steps ›" expands). Done only (no Skip).
- FR-15 Module Guardian's turn at the end of Modules 1 and 2.

### Games (details in EXERCISES.md)
- FR-16 Type 1: character shown, child taps its piece. Levels 1–6.
- FR-17 Type 2: piece shown, child taps its character. Levels 1–6.
- FR-18 Type 3: drag a character card onto its piece card; the line draws itself. Levels 1–6.
- FR-19 Type 6: team shelf, drag figures into silhouette slots, 1·1·2·2·2·8 spoken as groups fill. Levels 1–6.
- FR-20 Type 8: two kings, two houses (2 × 8), figures come from a basket in batches. Levels 1–6.
- FR-21 Wrong tap: card sinks 16 pt, dims, lilac dashed outline. Wrong drop: springs back softly. No voice on a wrong answer except the hint line.
- FR-22 Hint ladder: 1 clue card (story still) → 2 arrow → 3 result (answer lights up, names itself, exercise ends without a tap).
- FR-23 Hints step up after a wrong answer or after 12 s idle (18 s in Calm or Wobbly).
- FR-24 Correct: moss ring + one 8 pt bounce + the animal says "I'm the King!" (or the type's correct line); Guardian taps Next.
- FR-25 Input locked while feedback, hints or clips play.
- FR-26 The level is chosen by the engine between rounds; the child never sees it.

### Mood and breaks
- FR-27 Mood check (one-finger long press 2 s on the Guardian button, ring fills): Ready / Wobbly / Needs a break.
- FR-28 Planned break after the Module 1 Guardian's turn; break picker: 4 activities, 1/2/3/5 min (default 2).
- FR-29 Break running: character models the activity, leaf timer, Add 1 minute, End break (Guardian).
- FR-30 Check-in suggestion: Guardian button glows softly when the engine sees struggle. Nothing else changes.

### End
- FR-31 Play together: six animal + piece pairs, two prompts, We're done.
- FR-32 Lesson complete: full cast; Guardian summary in words only ("Knows the Rook well", "Still learning the Knight", breaks taken).
- FR-33 After completion, Lesson 1 stays playable as practice.
- FR-34 (Later) On-device AI summary.

## 7. Adaptive engine
Summary; full spec in `docs/ENGINE.md`.
- BKT on 8 skills: King, Queen, Rook, Bishop, Knight, Pawn (Types 1 and 2 share one score per piece), Colour, Team make-up.
- P(L₀) 0.10 · learn 0.15 · slip 0.10 (0.30 when Wobbly) · guess = 1 ÷ choices.
- P(known) chooses the v6 level 1–6; max one level step per round; 0.05 buffer; Wobbly plays one level lower.
- Evidence: correct with no hint = correct; after Hint 1 = correct with higher guess; after Hint 2 = no update; Hint 3 = wrong; taps faster than 40% of the child's usual time are ignored.
- Mood is set only by the Guardian.

## 8. Non-functional requirements
| Area | Requirement |
|---|---|
| ASD design | Fixed positions; one thing per screen; no red, X, score, visible level, round dots; each colour one role plus a shape change; no flashes, shakes or fast spins; celebrations under 1 s |
| Sensory | No music. Every child line voiced. Calm: plain surface, ~30% less saturation, fades instead of transformations, effects ~40% quieter, no leaf particles |
| Language | One question pattern. Literal instructions. Jokes only inside story narration. Captions match narration word for word |
| Accessibility | Reduce Motion honoured; VoiceOver labels on Guardian controls; Dynamic Type on Guardian text only; contrast ≥ 4.5:1 |
| Touch | Choice cards ≥ 200 × 240 pt at levels 1–3 and 5–6 (level 4: 168 × 210, see DECISIONS); drag cards ≥ 120 × 140 pt; child buttons ≥ 64 pt high; Guardian buttons ≥ 56 pt; ≥ 24 pt between targets |
| Privacy | No network, accounts, analytics, ads, purchases or export. SwiftData on device. App Store label "Data Not Collected" |
| Claims | No therapy or clinical claims anywhere |
| Performance | Launch to lesson map < 2 s (after launch animation); scene change < 300 ms; feedback < 100 ms after a tap; 60 fps in SpriteKit on the oldest iPadOS 26 iPad |
| Reliability | Works offline from first launch; progress survives quit, crash, restart |
| Platform | iPadOS 26+, iPad only, landscape. Designed at 1194 × 834 pt; 13-inch (1376 × 1032) scales with the same zones |
| Size | No limit; quality first |

## 9. Content
- Story world: Sixty-Four Wood; Ivory Hollow (King Sunmane) and Charcoal Ridge (King Duskmane); Pip the parrot carries the scroll.
- Cast (both teams): lion = King, lioness = Queen, elephant = Rook (gold notched headpiece), horse = Knight, fox = Bishop (owl under review), squirrel = Pawn.
- Voice: ElevenLabs, bundled files only. Cast and settings in `docs/VOICE.md`; every line in `Content/Lesson1/voice_lines.csv`.
- Art: full list in `docs/ASSETS.md`. All video (film, transformation clips, charcoal intro) is made by the video team and delivered with the names in `manifest.json`.
- No word "Amazon" anywhere.

## 10. Open items
See `docs/DECISIONS.md` § Open.
