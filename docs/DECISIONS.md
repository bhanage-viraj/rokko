# Decisions

## Decided (12 Nov 2026)
**Scope**
- Lesson 1 only, no deadline. Exercise Types v6 is the only source for the games, white and black.
- Lesson 1 games: Module 1 (Types 1, 2 · King, Rook, Knight), Module 2 (Types 1, 2 · Queen, Bishop, Pawn), Module 3 (Types 3, 4, 5: linking, team shelf, both teams; numbered as in the exercise pool, 13 Nov).
- Story splits: meet King, Rook, Knight → Module 1 → meet Queen, Bishop, Pawn → Module 2 → Module 3.
- The charcoal team is introduced in a short scene before the first level-5 round.
- Lesson 1 runs over several sittings and resumes where it stopped.

**Games**
- Untaught pieces may appear as wrong options.
- Level 5 = 4 mixed-colour options without the black twin; level 6 adds the black twin.
- The target is always white in Modules 1–2.
- "I'm the King!" plays after the correct tap. Each animal has its own reward motion.
- Hint 1 = half-transparent clue card, the animal's front half (its face, no tail) on the left and the piece's face half on the right, faces meeting in the middle; each half scaled to fill its side, the pair centred. Rook: the elephant (facing left, no tail) is cut through the tower on its back and meets the Rook's half tower, top-aligned, so the two halves make one tower (`ClueHalf` in ItemArt.swift), drawn in code from the character and piece art (14 Nov; was a story still). It stays up through Hint 2 (the arrow joins it) until that target is done (15 Nov). It sits in a free corner / side-middle of the stage, never over a card, slot or house, nearest the figure; Hint 3 shows the answer and ends the exercise with no tap and counts as not known.
- Hints step up on a wrong answer, after one free try per target. No idle hints (2026-11-13: timed hints appeared while the Guardian was still explaining and solved the game for the child); if re-enabled, idle 12 s (18 s Calm/Wobbly) and never past the arrow. Drag hints go to the next unlinked pair / empty slot; in Type 3 they go to the pair the child just missed (the dragged card and its partner), and a miss on another pair starts the ladder again for that pair (14 Nov).
- Linking: drag either card onto its partner (animal → piece or piece → animal, 14 Nov); Levels 1–4 are two columns, "match the column" style (14 Nov): animals left, pieces right, a small dot on each card's inner edge, matched cards get a soft leaf tint (moss wash) with a thin moss edge and a filled moss dot instead of the thick moss ring, and a little vine grows along a smooth curve from dot to dot and stays (15 Nov: thin moss stem, leaves appear one by one on alternating sides; `vine_leaf.png` when added, else drawn in code). Cards do not move while dragged (15 Nov): the card glows and a faint dashed vine (with faint leaves) runs from its dot to the finger; letting go on a card on the other side makes the link. Cards are 190 pt wide and shrink in height to fit the column (about 82 pt for 6), below the PRD's 120 × 140 drag-card minimum. Levels 5–6 keep their bands, with a gently bent line from the facing edges. 10-pair level split into two parts. Level 6 shade is neutral grey-brown.
- Drag games (Types 3–5) also take two taps: tap a figure (it lifts with a faint honey glow), then tap where it goes. Same `.drop` event, same rules. Tap the figure again or empty space to put it down (14 Nov: young children often lift the finger mid-drag; NN/g recommends a tap alternative). Every card has 16 pt extra touch area (`layout.touchSlop`); a drag starts after 10 pt (`layout.dragStartDistance`); snap distance 44 → 64 pt.
- While dragging, the target under the figure (piece card, slot or house) shows a faint honey glow and grows to 1.05 (no grow in Calm / Reduce Motion). It shows for any target, right or wrong.
- No haptics: iPads have no Taptic Engine (only Apple Pencil Pro / some trackpads), so feedback stays visual + voice.
- Calm background (14 Nov): the clearing stays, blurred 80 pt, saturation −30%, paper wash 45%, instead of flat paper.
- Captions type themselves out (14 Nov): letters fade in one by one, 60 ms apart (`motion.captionCharMs`); hidden letters keep their space so the line never moves.
- Child copy rewritten to be literal (14 Nov): short sentences, one idea each, no idioms ("the whole team is home") or abstract words ("brave", "leader", "keep him safe"). Meet lines name one thing to look at; transformation lines say the piece keeps it. Story names (King Duskmane, Charcoal Ridge) dropped from the charcoal intro. Rules in VOICE.md. No files were recorded yet, so nothing needs re-making.
- Cheers vary (14 Nov): every right answer is preceded by a short cheer and every finished shelf / teams game by a finish cheer, each its own voice file. `CheerPicker` (RokkoEngine) picks it from the round code: words change every time, never twice in a row, and the same round always says the same cheers. Hint-3 reveals get no cheer.
- Supporting line on a try that does not fit (14 Nov; changes PRD FR-21 "no voice on a wrong answer except the hint line"): a calm line that changes each time (`VoiceKeys.encouragements`, picked like the cheers) is said on its own (15 Nov: no question after it; "Good try. Find the King." read badly). When a hint step is due, only the hint line is said. Never "wrong", "no" or "mistake".
- Hint 1 says what matches (15 Nov): "Look at this. The elephant has a tower. The Rook is a tower too." (`l1_h1_match_<piece>`, one per piece, same features as the meet / transformation lines). Hint lines are said alone: no question or instruction after Hint 1 or Hint 2. Replaces "Let’s look again." + question.
- Type 3 "show me" (15 Nov): at the start of each matching round (columns layout), the first animal glows and a faint vine grows from its dot about 70% of the way toward the pieces column, fades, and plays again (2×, `motion.linkDemo*`). It never reaches a piece (shows the move, not the answer), never locks input, and stops at the first touch. Calm / Reduce Motion: the vine fades in instead of growing.
- Type 3 one animal at a time (15 Nov, columns layout): only the first animal not yet matched is sharp and can be dragged (or have a piece dropped on it); the others wait blurred (10 pt) and faded (45%) and can't be touched. All pieces stay clear. When an animal is done, the next one un-blurs as its vine grows. Hints help with the animal that is up (`layout.linkWaiting*`).
- Black shelf uses piece shapes. Wrong-colour figures spring back. Counts spoken as each group fills. Pawns in two rows of 4.
- Type 5: figures come from a basket in batches; houses are 2 × 8 grids.
- Codes `LLL-M-TT-EE-V-III` are the real IDs; III = pool row number (13 Nov; was "Id = variation").

**Engine**
- BKT stays. One score per piece shared by Types 1 and 2; plus Colour and Team make-up skills.
- Hint 2 correct = no update. Fast-tap guard 40% of the child's median.
- Gates 0.60 / 0.75. Lesson complete when all skills ≥ 0.95.
- Wobbly = one level lower + slower hints. Parents see words only.

**Tech**
- Claude Code builds; you review. GitHub repo.
- iPadOS 26+, landscape, iPad only, one child per iPad, no iCloud.
- SwiftUI shell; SpriteKit for all games (one SKView); transformation clips as SKVideoNode.
- Rounds come from the exercise pool (13 Nov; was "generated from v6 rules"); fixed seeds set positions only. Clue cards from story stills. PNG + SKAction motion.
- Guardian controls: long press the Guardian button 2 s for the mood check; settings in the Guardian menu. No data export at all.
- English, strings table ready for more languages. No app size limit.
- You generate the voice lines from the CSV.
- Unit tests for engine and generator (no learner simulator).
- Lesson 2 plugs in as a content pack + new scene types.

**Video**
- All video (opening film, transformation clips, charcoal intro) is made by the video team. The app only plays the files named in `manifest.json`.

**Design kept from the canvas**
- No round dots, no Skip, no speaker/replay button. Guardian screens show the Guardian symbol + "Guardian" (16 Nov; was "Guardian's turn"). Again is a ↻ symbol just left of Next (decided 12 Nov; was above Next).
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

**Exercise pool (13 Nov 2026)**
- Lesson_1_Exercise_Pool is the source for every round (690 rounds): `Content/Lesson1/exercise_pool.json`, re-imported with `Tools/import_exercise_pool.py`.
- Module 3 types renumbered to match the pool: team shelf = Type 4 (Ex 03–04), both teams = Type 5 (Ex 05–06). Voice keys `l1_t6_*` → `l1_t4_*`, `l1_t8_*` → `l1_t5_*` (not yet recorded).
- Look-alikes: King ↔ Queen, Rook ↔ Pawn, Knight ↔ Bishop, Bishop ↔ Pawn (closes O3).
- Linking level 1 uses any 4 of the six (not a fixed set); level 3 mixes 3–6 of one colour; level 6 links each shaded character to both pieces.
- Team shelf level 6: the 6 other-colour figures vary per round; black shelf distractors are white pieces.

**Lesson flow built (15 Nov 2026)**
- `LessonCoordinator` runs every step of `lesson1.json`; `RoundPlanner` (RokkoEngine) picks each round, the level and the pool round. BKT, planner, exercise plays and session events are saved after every step and round.
- Videos are blank for now: a clip's slot shows an empty card for `story.clipPlaceholderSeconds` (2.4 s), then the step carries on (transform: animal + piece "after" state with Again).
- Pause shows Resume plus a small "Leave lesson" (keeps the exact place), so the Guardian can get back to the lesson map. FR-09 said Resume only.
- No audio files yet: lines said in a row (charcoal intro, lesson complete, breaks) show one after another, each held `story.captionHoldMs` after it types out.

- Team shelf (Type 4) and both teams (Type 5) left out of Module 3 for now (15 Nov: too many long rounds; the child got bored). `planner.module3Cycle` is Type 3 only (white, black), and Team make-up and Colour are out of the lesson-complete gate (only those games teach them). Put them back to bring the games in.

- Each module is 3–6 rounds (15 Nov): it ends after 3 once its gate is met, and always after 6 (`planner.blocks.*.minRounds` / `maxRounds`). Gates no longer hold a module open. DEBUG builds show "DEV · Skip exercise" above a round.

- Level 1 only for now (16 Nov; was level 3 on 15 Nov): `levels.maxLevel: 1`; LevelSelector never picks more. Levels 2–6 stay in the pool for later.
- Black team intro (15 Nov; replaces "before the first level-5 round"): shown once, just before the first round that has anything black in it (with the level-3 cap: the black matching game or a mixed level-3 matching round in Module 3). The child never meets a black piece unannounced. Three steps, each on Next, no video needed (L1_CH01 can join later): (1) the six white animals, their black twins appearing under them one by one (`l1_ch_01`–`04`); (2) the same for the pieces (`l1_ch_05` "These are the black pieces. They have the same shapes."); (3) Guardian's turn (blue): "Get the black pieces", one of each next to the white ones (setup only asked for the white pieces). Black pieces are the white art tinted slate until `piece_<name>_charcoal.png` exist.

## Superseded in the old PRD (8 Nov)
FR-14 Skip · FR-22 round dots · FR-11 replay button · FR-24 hold on Pip · 2/3/4-card BKT bands · "Types 3–8 later" · old colour tokens · scheme name ChessJungle · two-week TestFlight date.

## Open (need your answer)
| # | Question | Current assumption in the files |
|---|---|---|
| O1 | Bishop: fox or owl? | kangaroo (14 Nov: the new character sheet has a kangaroo; replaces the fox everywhere) |
| O2 | Squirrel voice | none; its reward line is blocked |
| O3 | ~~Look-alikes for Rook and Knight at level 2~~ | closed 13 Nov by the exercise pool: Rook ↔ Pawn, Knight ↔ Bishop |
| O4 | Final character heights | elephant 1.35 (15 Nov: was 1.10, looked too small next to the lion), lion 1.00, horse 0.95, lioness 0.92, kangaroo 0.70, squirrel 0.40 |
| O5 | Words for the teams to the child | "white" and "black" (story names Ivory Hollow / Charcoal Ridge stay in the film) |
| O6 | Guardian controls | pause = tap (Resume only); Guardian button: one-finger long press 2 s = mood; menu from lesson-map Settings (decided 12 Nov) |
| O7 | Level 4 choice cards are 168 × 210 pt (below the 200 × 240 minimum) | allowed as an exception |
| O8 | Module Guardian's turn content | hold up the module's pieces; child points to each and names the animal |
| O9 | Max rounds per sitting | 14 / 14 / 10, then "Stop here for today" or "Keep going" |
| O10 | One voice model for the whole app | eleven_multilingual_v2 (as the film) |
| O11 | Type 3 levels 5–6 layout | as written in EXERCISES.md, needs your sketch to confirm |
| O12 | Commercial licence for final Recraft art | paid plan before final art |
- 13 Nov 2026: Type 4 shelf and Type 5 houses show one of each piece (K Q R B N P) per team, not a full 16-piece set (16 figures was too much on screen). The pool is unchanged; `RoundGenerator.onePerPiece` reduces each round. Count lines are now "One <Piece>!", end line "Six! The whole team is home." Open: PRD goal 3 ("a team has 16 pieces") is no longer taught by these games.
- 16 Nov 2026: Black piece shelf (Type 4 Ex 04) shows the whole team of 16 again (2 Rooks, 2 Bishops, 2 Knights, 8 Pawns) on two tiers; the white character shelf (Ex 03) stays one of each. Set by `generator.shelfFullTeamForms`. New voice lines `l1_t4_count_{rook,bishop,knight}_2`, `l1_t4_count_pawn_8`, `l1_t4_done_full` (to record).
- 17 Nov 2026: The opening film is "The Day the Jungle Changed", cut into 8 clips (story, kings, queens, elephants, kangaroos, horses, squirrels, ending) replacing the placeholder L1_OP01–OP07 steps. Each clip plays in AVPlayer (no controls), filling the screen edge to edge down to the caption row, with the top bar floating over it; when it ends, Next lights up and Again (↻) replays it, nothing advances on its own. Subtitles come from `Content/Lesson1/Subtitles/*.subtitles.json`: shown in the same caption as every other line (plain text), one line at a time, appearing word by word in step with the voice: each cue carries its measured speech stretches (`Tools/subtitle_speech_spans.py`) and the clip time decides which words show, so pause, Again and backgrounding cannot put them out of step; a speaker tag ("Horse: \"") shows at once. When a clip ends it holds its last bright frame (`manifest.json › endStill`), slightly dimmed, with "✓ Finished" (the film's narration is the video team's, so these lines are not in voice_lines.csv). Open: the film names (Checkerwood Jungle, Sunrise/Moonlight Kingdom, King Sunny/Moony) differ from the in-app lines (Sixty-Four Wood, Ivory Hollow, Charcoal Ridge).
- 17 Nov 2026: All 121 in-app voice lines recorded with ElevenLabs (eleven_multilingual_v2, one take each, voices per docs/VOICE.md; squirrel = Teddy Twinkle – Cute Cartoon Boy) and bundled in `Resources/Audio/Voice/` via `Tools/process_voice.sh` (−16 LUFS, 48 kHz mono, trimmed, AAC). `VoicePlayer` plays them; each caption shows while its line plays; lines in a row have a 250 ms gap (`story.voiceGapMs`); Sound off = captions only. A clip the video team has not delivered is skipped instead of showing a blank card (`story.clipPlaceholderSeconds: 0`). Still to make: the 6 transformation clips (L1_TR_*) and the black-team clip (L1_CH01), in the film's 2D style.
- 19 Nov 2026: Opening film v5 at 24 fps (was 12): characters have a bone rig with skin weights and springs (tails, ears, trunk follow through and settle; chest breathes; head nods with the voice), backgrounds have slow wind, soft light, pollen, a few butterflies and falling leaves (none during the scroll and rule scene). Same scene times, so subtitles and `endStill` are unchanged. Tools in `Tools/film/` (dev only). Not Rive: the app stays Apple-frameworks-only; the film is plain video.
- 19 Nov 2026: The six transformation clips are made (`Tools/make_transform_clips.py`), Standard and Calm (Calm = cross-fade only, PRD Sensory). `ContentValidationTests.everyTransformationClipIsDelivered` checks all 12 files.
- 19 Nov 2026: Opening film v6 (24 fps) replaces v5: keyframed layer rigs built from the original character art (tools in `Tools/film/`), source `Media/Source/Lesson1_The_Day_the_Jungle_Changed_v6.mp4` (not shipped), cut into the same 8 clips. The 6 transformation clips (`Tools/make_transform_clips.py`, Standard 2.8 s, Calm 2.4 s) are delivered. Each `endStill` is the last bright frame before the clip's fade to dark (film: seconds − 0.458; transformations: 2.35 s, inside both the Calm and Standard file), checked against the files by `ContentValidationTests.manifestTimesMatchTheVideoFiles`; `rokkoTests/ClipBundleTests` checks all 20 files are in the app bundle.
- 23 Nov 2026: Transformation clips play in `ClipSlot` (AVPlayer via `ClipPlayer`, the same player as the film), not in an `SKVideoNode` inside MeetScene as ARCHITECTURE.md describes. Kept as is: one player gives one pause / background / Again path for every clip, and the "after" picture (`TransformedStage`) is SwiftUI. Calm mode, a wobbly mood and iOS Reduce Motion all get the Calm file. Again stops the transformation's voice line before the clip replays.
