# Assets · Lesson 1

Everything the code expects, with exact file names. A missing file must fail `ContentValidationTests`.
Status: **have** = usable now · **draft** = exists but not final art · **make** = not started · **code** = drawn in code, no file.

Final art must be on a commercial licence (paid Recraft plan, or redrawn). Drafts made on a free plan cannot ship.

## 1. Characters (12 + optional owl)
PNG, transparent, standing, three-quarter view. Ivory faces right; charcoal is the same pose mirrored (faces left), slate recolour, same gold anchors.
Size: tallest (elephant) 1400 px high; others scaled by DESIGN_SYSTEM heights. Put them in `Characters.spriteatlas`.

| File | Animal / piece | Status | Note |
|---|---|---|---|
| `char_lion_ivory.png` | lion · King | draft | final pose made; match king scale |
| `char_lioness_ivory.png` | lioness · Queen | draft | |
| `char_elephant_ivory.png` | elephant · Rook | make | gold notched headpiece replaces the tower on the back |
| `char_horse_ivory.png` | horse · Knight | draft | |
| `char_fox_ivory.png` | fox · Bishop | draft | or `char_owl_ivory.png` if the owl wins (DECISIONS O1) |
| `char_squirrel_ivory.png` | squirrel · Pawn | draft | new squirrel chosen for both teams |
| `char_lion_charcoal.png` | King Duskmane | draft | |
| `char_lioness_charcoal.png` | | draft | |
| `char_elephant_charcoal.png` | | make | |
| `char_horse_charcoal.png` | | draft | |
| `char_fox_charcoal.png` | | draft | |
| `char_squirrel_charcoal.png` | | draft | |

Shaded characters (Type 3 level 6) and slot silhouettes (Type 6, 8) are **code**: tint the same PNG with `colorBlendFactor`.

## 2. Chess pieces (12)
PNG, transparent, side view, same style as the launch screen King and Rook. Height: King 1000 px, others in real Staunton proportion.
`Pieces.spriteatlas`.

| File | Status |
|---|---|
| `piece_king_ivory.png` | have (launch set) |
| `piece_rook_ivory.png` | have (launch set) |
| `piece_knight_ivory.png`, `piece_queen_ivory.png`, `piece_bishop_ivory.png`, `piece_pawn_ivory.png` | make (match the launch King and Rook) |
| `piece_<name>_charcoal.png` × 6 | make (same set, slate charcoal, gold-free) |

## 3. Hint 1 clue cards (12)
Still frame from each animal's transformation clip (the moment the piece shape is visible on the animal). Export once the video team delivers the clips, or ask them to export these stills. 600 × 720 px PNG, honey edge drawn in code.

| File | Status |
|---|---|
| `clue_<piece>_ivory.png` × 6 | make (from the video team's clips) |
| `clue_<piece>_charcoal.png` × 6 | make (from the charcoal intro clip, or recolour) |

## 4. Game props
| File | Use | Status |
|---|---|---|
| `prop_shelf.png` | Type 6 team shelf, 3 tiers (back row 8 slots, pawns 2 × 4) | make |
| `prop_basket.png` | Type 8 batch basket | make |
| `prop_house_ivory.png`, `prop_house_charcoal.png` | Type 8 houses behind the 2 × 8 slots (soft, low contrast) | make (optional; code fallback = rounded panel) |
| `prop_scroll_open.png` | Pip's scroll | have |
| Slots, link lines, arrows, rings | | code |

## 5. Backgrounds
| File | Use | Status |
|---|---|---|
| `bg_clearing.jpg` | Misty Clearing, child screens (Standard) | have (`bg.jpg`) |
| `bg_kingdom_ivory.png` | Ivory Hollow ledge | have (`kingdom.png`, lion inpainted out) |
| `bg_kingdom_charcoal.png` | Charcoal Ridge | draft (mirrored and darkened, needs real art) |
| `tex_noise.png` | paper grain overlay | have |
| Calm background | flat `paper` | code |

## 6. Pip
| File | Status |
|---|---|
| `pip_perch.png` | have (`parrot.png`) |
| `pip_glide.png` | have |

## 7. Video: not in this list
All video (opening film L1_OP01–OP07, transformation clips L1_TR_*, charcoal intro L1_CH01, Calm and Standard versions) is made by the video team, not from this list.
The code only needs the files to arrive with the names in `Content/Lesson1/manifest.json` (HEVC 1080p, 30 fps). Until then it shows a placeholder.

## 8. Audio
Voice: 94 in-app lines in `Content/Lesson1/voice_lines.csv` (93 to make, 1 blocked: squirrel voice). Film narration belongs to the video team. `Resources/Audio/Voice/<id>.m4a`.

Sound effects (`Resources/Audio/SFX/`, soft, under 0.6 s, no buzzers):
| File | Use | Status |
|---|---|---|
| `sfx_tap.wav` | card press | make |
| `sfx_correct_chime.wav` | correct | make |
| `sfx_lift.wav` | drag start | make |
| `sfx_snap.wav` | correct drop / link | make |
| `sfx_spring.wav` | soft spring back (wrong drop) | make |
| `sfx_transform.wav` | animal becomes piece (if not in the clip) | make |
| `sfx_hold_done.wav` | hold ring complete | make |
| `sfx_page.wav` | step change | make |

## 9. UI icons (SVG, single colour, 64 pt grid)
Child-facing icons are custom; Guardian screens may use SF Symbols.
| File | Status |
|---|---|
| `ic_pause`, `ic_guardian` (two people), `ic_next`, `ic_again` | have on canvas, export as SVG |
| Lesson path: `ic_step_story`, `ic_step_meet`, `ic_step_guardian`, `ic_step_game`, `ic_step_break`, `ic_step_play`, `ic_step_done` | have on canvas, export |
| Mood: `ic_mood_ready`, `ic_mood_wobbly`, `ic_mood_break` | have on canvas, export |
| Break: `ic_break_move`, `ic_break_breathe`, `ic_break_quiet`, `ic_break_own` | have on canvas, export |
| Leaf particles `fx_leaf_1…3.png` | make |

## 10. Brand
| File | Status |
|---|---|
| `logo_rokko.svg` (circles + arc + wordmark) | make (clean vector from the chosen logo) |
| App icon 1024 × 1024 | make |
| Launch: `KingIvory.png`, `RookIvory.png`, `Fredoka-SemiBold.ttf` + `RokkoLaunchView.swift` | have |

## 11. Fonts
`Fredoka-SemiBold.ttf`, `Nunito-Regular/SemiBold/Bold.ttf` (OFL). have.

## 12. Reward motions (code, ≤ 1 s each, both teams)
lion: crown glints · lioness: crown settles · elephant: lifts trunk · horse: nods mane · fox: ears twitch · squirrel: tail flick. Calm/Reduce Motion: soft fade of the piece symbol only.

## Counts
| Group | Files | To make |
|---|---|---|
| Characters | 12 | 2 + finals of 10 drafts |
| Pieces | 12 | 10 |
| Clue cards | 12 | 12 |
| Props | 4 | 3 |
| Voice | 94 | 93 + 1 blocked |
| SFX | 8 | 8 |
| Icons | 21 + leaves | export + 3 |
