# First-run setup (onboarding)

Shown once, after the launch animation and before the lesson map, while `AppSettings.onboardingDone` is false.
Guardian only. No voice lines. Replaces the old Before you start, Calm or Standard and
Get your pieces ready screens (PRD FR-02..FR-04). Code: `rokko/App/Onboarding/`.

Next is the main button from the very first screen, so it is not taught separately.
Copy is kept to one line per screen: no eyebrows, no subtitles, no tile descriptions, and no lesson captions.

## Order

| # | Step | Shown as | Moves on when |
|---|---|---|---|
| – | `welcome` | page | Next (always on) |
| 1 | `chess` | page | Next, once a choice is picked |
| 2 | `look` | **app** | Next, once a look is picked |
| 3 | `tryGuardian` | **app** | Next (straight away, like everywhere else) |
| 4 | `tryCheckIn` | **app** | by itself, 2.6 s after a mood is picked |
| – | `ready` | page | "Start Lesson 1" |

**Pages** (welcome, chess, ready): top bar with Back (‹, round 56 pt) · 4-segment progress + "Step N of 4"
("About 1 minute" on welcome) · Skip (⏭, round 56 pt); main button (Next, or "Start Lesson 1" on ready) bottom-right, in exactly the spot where the lesson's Next sits on the app steps, faded until the step is done.
No Back on welcome; no top bar on ready.

**App steps** (look and the two practice steps): the same setup bar stays at the top (Back · progress ·
Skip). The real lesson frame sits just below it, scaled to the height left (≈ 0.87), with rounded corners,
in practice mode and without captions. A small cream speech bubble gives the one-line instruction, with a
tail pointing at what to tap; the lesson screen dims softly around a gentle honey ring on that target.
The look and Guardian's-turn steps use Next. The check-in has no Next: once a mood is picked, a moss tick shows by
"Step N of 4" and the next step opens by itself. Going Back into a practice step resets it, so it is done again.

**Skip** is blurred and does nothing until both chess and look are answered (they change the app).
After that it jumps to ready; only the practice steps can be skipped.

## Screens

- **welcome** — castling circles · **Learn chess, side by side.** · Next.
- **chess** — **Do you play chess?** · three tiles with a piece picture: Not yet (pawn) · A little (knight) · Yes (king).
- **look** — full lesson screen with the lion. Card: **How do busy screens feel?** with two choices
  "Calm" / "Standard". The whole screen switches live: Calm (plain paper) ↔ Standard (painted clearing), so both
  can be compared. The lesson's own **Next** (faded until a look is picked) moves on.
- **tryGuardian** — blue Guardian's turn: King + "Show the real King" panel (full steps or one line, from the chess answer).
  Bubble on the Guardian's-turn panel (the panel is ringed, not Next): "Blue screens are **your turn**. Pick up the real King and show it to your child."
  The goal is what these blue screens are for, not the button. Next moves on straight away, as everywhere else.
- **tryCheckIn** — a Type 1 round (no caption). Bubble on the Guardian button: "**Press and hold** here for 2 seconds."
  Everything except the Guardian button is blurred (not just dimmed), so the only thing in focus is where to hold.
  One-finger long press, 2 s, ring fills; letting go early stops the ring at the share of 2 s held and empties it from there.
  → mood drop-down grows down out of the Guardian button: one tall pill, three round choices with short labels
  (Ready ☀ / Wobbly ⛅ / Needs a break 🌙). Tap outside closes it. While it is open, the pill is ringed and a bubble to its
  left, tail pointing at it, headed "How is your child?", explains them: "**Ready**: carry on as normal. / **Wobbly**: slower, easier rounds. / **Needs a break**: take a short break."
  → pick → sheet closes after 0.7 s → bubble shows the reply, then the next step:
  Ready: "the lesson carries on as normal." · Wobbly: "Rokko slows down and makes the next rounds easier." ·
  Needs a break: "a short break starts, and you pick the activity." The practice mood is not saved.
- **ready** — castling circles · **You're ready.** · chips (Calm/Standard look · Full/Short tips) · CTA "Start Lesson 1" → lesson map.

## Practice mode
The full-screen steps use the real lesson frame components (`rokko/App/LessonFrame/`) with
`LessonFrameMode.practice`: no engine calls, no BKT updates, no SessionEvents, no lesson progress saved.

## What gets saved (on "Start Lesson 1")
| Answer | Saved |
|---|---|
| chess | `AppSettings.tipsMode`: Not yet → `.full`; A little / Yes → `.short` |
| look | `AppSettings.calm` (Calm → true) |
| – | `AppSettings.onboardingDone = true` |

## Effects
- `tipsMode` decides full steps vs one line on every Guardian's turn (`GuardianTurnPanel`).
- Pieces are not part of setup: the lesson shows the pieces checklist once before its first Guardian's turn
  (`AppSettings.needsPiecesReminder`, `PiecesChecklist`). Wire in when the LessonCoordinator lands.
- Guardian menu (gear, top-right of the lesson map): Calm/Standard, sound, Guardian's-turn tips, "Run setup again".
