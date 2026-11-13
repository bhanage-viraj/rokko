# Design system · Misty Clearing

Screens: Lesson 1 hi-fi canvas (64 artboards) and `Lesson1_Hifi_Misty_Clearing.pdf`. This file is what code needs.

## Colour tokens (`RokkoColor`)
One colour, one meaning. No red anywhere, including art.

| Token | Hex | Role |
|---|---|---|
| `paper` | #F4F0E3 | Child screens background, Calm surface |
| `mistBlue` | #DCE7EA | Guardian screens only |
| `card` | #FBF8EF | Cards, bars, dialogs |
| `cardEdge` | #DAD3BD | Card border (3 pt) |
| `leaf` | #2F4A3E | Primary buttons (Next, Done) |
| `ink` | #2D3A31 | Text |
| `inkSoft` | #5D6A5F | Secondary text |
| `honey` | #E2B24A | Hints, glows, arrow, clue edge |
| `moss` | #5E9A5A | Correct ring, link lines |
| `lilac` | #A597D2 | Try again (dashed outline only) |
| `sageDone` | #C3D5AC | Finished path steps |
| `teal` | #4A7890 | Guardian labels, hold rings |
| `bark` | #5B4636 | Character name labels |

Brand (logo, launch): cream #F4F0E3, leaf #2F4A3E, honey #E2B24A, tile moss #A9B98C.
Team colours: ivory and charcoal (slate, never pure black); gold anchors on both teams.
Calm mode: same tokens, backgrounds replaced by `paper`, art saturation −30%.

## Type
- **Fredoka SemiBold**: questions 34 pt, buttons 30 pt, labels 26 pt, titles.
- **Nunito**: captions 26 pt Bold, Guardian body 20 pt Regular/SemiBold.
- Child text is fixed size; Dynamic Type only on Guardian text.
- Both fonts are SIL Open Font License, so they can be bundled.

## Layout (1194 × 834 pt)
| Zone | Frame |
|---|---|
| Top bar | y 0–112: pause (left, 64 pt), lesson path (centre), Guardian button (right, 64 pt) |
| Stage | y 112–680 |
| Question area | centred, y 150–330 (shown figure) |
| Answer row | y 400–680 |
| Caption bar | x 40, y 698, height 96, width 900 |
| Next | bottom-right, 180 × 100, right 40, bottom 34 |
| Again | ↻ symbol only, 80 × 80 circle, 3 pt leaf ring; same row as Next, 16 pt to its left, centred on it |

Margins 40. Spacing scale 4 · 8 · 12 · 16 · 24 · 32 · 40 · 56 · 80. Radii: card 28, panel 32, dialog 40, buttons pill.
Shadows: warm only, two levels: `0 6 16 rgba(45,58,49,.10)` and `0 8 26 rgba(45,58,49,.16)`.
13-inch: scale zones by 1376/1194, keep positions relative.

## Card states
idle · pressed (0.97) · faint glow (honey 30%) · strong glow (honey 70%, 8 pt) · try again (sunk 16 pt, 60% alpha, lilac dashed 3 pt) · correct (moss ring 6 pt) · dimmed (40% alpha).

## Characters
- Single PNG per character per team, standing, three-quarter view facing right, transparent background, warm dark-brown outline, soft painterly cel shading.
- Charcoal team: same pose, mirrored to face left, slate recolour, same gold anchors.
- Relative heights (lion = 1.00): elephant 1.10, lion 1.00, horse 0.95, lioness 0.92, fox 0.70, squirrel 0.40. Confirm against the final Recraft art.
- Motion in code only: breathe (scale Y 1.0→1.015, 4 s loop), lift on correct, gentle settle.

## Motion rules
Screen change 300 ms cross-fade; card press 120 ms; correct 350 ms; try-again 300 ms; arrow bob 6 pt 1.2 s loop; transformation clip ~2.4 s; no flashes, shakes or fast spins; celebrations < 1 s. Reduce Motion and Calm: fades only.
