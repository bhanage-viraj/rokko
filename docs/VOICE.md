# Voice

Every in-app line the child hears is a pre-made ElevenLabs file bundled in the app. Never generated live. Film narration is the video team's job and is not in this list.
All lines, IDs and captions: `Content/Lesson1/voice_lines.csv` (one row per file).
You generate the files; the CSV is the script.

## Cast
One fixed voice per character, never changed. Charcoal animals use the same voice as their ivory twin, except the two kings.

| Speaker key | Character | Voice | Voice ID |
|---|---|---|---|
| `narrator` | Narrator | Kimberly – Warm, Calm, Natural | w2CTE3MYza6FgBnETYNT |
| `pip` | Pip the parrot | Pip the Parrot v3 (custom) | BAikf2QimDRx504rl6jJ |
| `lion` | King Sunmane (ivory lion) | Grant – Deep British Male Narrator | cnq6HZP9Mrjsf97pVK6b |
| `lion_charcoal` | King Duskmane (charcoal lion) | Adam – Professional, Deep/Warm | w32tZFm9MHs6Mkjdo6Tl |
| `lioness` | Queen | Grandma Muffins Oxley | vFLqXa8bgbofGarf6fZh |
| `elephant` | Rook | K. V. Hagen – Deep Warm Natural | t1yzxMpe9zK42bXmI1T2 |
| `horse` | Knight | Amir – Calm, Natural Storyteller | YPRmL2oHPibcUwJtQnPM |
| `kangaroo` | Bishop (was the fox; same voice until a kangaroo voice is chosen) | Libby – Animated | Wu9A8zlwvFHoEpuX7MGo |
| `squirrel` | Pawn | Teddy Twinkle – Cute Cartoon Boy (chosen 17 Nov) | XjGYkUkzth8BPs29fmcV |

## Settings
- Model: one model for every line in the app (eleven_multilingual_v2 was used for the film; keep the same unless you re-make the film).
- Stability ~0.60, similarity 0.80, style ~0.15, speed ~0.90 (characters: stability 0.55, style 0.30).
- Calm and slightly slow. No shouting, no whispering, never sped up to fit.
- Export: 48 kHz mono, loudness normalised to −16 LUFS, peaks ≤ −1 dBTP, 150 ms silence trimmed to 40 ms at both ends.
- Bundle as AAC `.m4a`, named `<id>.m4a`, in `Resources/Audio/Voice/`.

## Lines that play together
Hints play two files in a row with a 250 ms gap, Hint lines are said on their own, with no question after them (15 Nov): `l1_h1_match_<piece>` names what matches ("Look at this. The elephant has a tower. The Rook is a tower too.") while the clue card shows; Hint 2 is "Look here." The caption shows both sentences together. Cheers work the same way: `l1_cheer_*` / `l1_finish_*` then the line (e.g. `l1_cheer_welldone` + `l1_ln_rook` → "Well done! The elephant is the Rook!"). `CheerPicker` chooses the cheer from the round code, so it changes every time but the same round always sounds the same; never the same cheer twice in a row.

## Rules
- Captions = the CSV `text` column, word for word.
- If a line changes, change the CSV, re-make the file, and check the caption.
- Never "wrong", "no", "mistake", "fail" or "Amazon".
- Child lines are literal (14 Nov): short sentences, one idea each, no idioms or figures of speech ("the team is home"), no abstract words ("brave", "leader", "safe"). Name the thing ("the King", "this piece"), not "he" / "this one", when it could be unclear. Meet lines name one thing to look at; transformation lines say the piece keeps it ("The King has the cross too."). Happy moments sound happy: a right answer is preceded by a cheer that changes each time ("Yes!", "Well done!", "That’s right!", "Good job!", "You got it!", "Great!"), a finished shelf or teams game by a finish cheer ("Hooray!", "You did it!", "Wonderful!", "Great work!"), new animals start with "Look!". Questions, hints and instructions stay calm, with no exclamation marks. After a try that does not fit, a calm supporting line that changes each time is said on its own ("That’s okay. Try again.", "Try again. You can do it.", "Keep going. You can do it.", "That’s okay. Look again.", "Let’s try one more time.", "Take your time. Try again."). When a hint is due, the hint line is said instead (15 Nov). Read the excited lines warm and bright, never shouted.
