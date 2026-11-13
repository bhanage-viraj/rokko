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
| `fox` | Bishop | Libby – Animated | Wu9A8zlwvFHoEpuX7MGo |
| `squirrel` | Pawn | **not chosen yet** | – |

## Settings
- Model: one model for every line in the app (eleven_multilingual_v2 was used for the film; keep the same unless you re-make the film).
- Stability ~0.60, similarity 0.80, style ~0.15, speed ~0.90 (characters: stability 0.55, style 0.30).
- Calm and slightly slow. No shouting, no whispering, never sped up to fit.
- Export: 48 kHz mono, loudness normalised to −16 LUFS, peaks ≤ −1 dBTP, 150 ms silence trimmed to 40 ms at both ends.
- Bundle as AAC `.m4a`, named `<id>.m4a`, in `Resources/Audio/Voice/`.

## Lines that play together
Hints play two files in a row with a 250 ms gap, for example `l1_h1_lookagain` then `l1_q_t1_king`. The caption shows both sentences together.

## Rules
- Captions = the CSV `text` column, word for word.
- If a line changes, change the CSV, re-make the file, and check the caption.
- Never "wrong", "no", "mistake", "fail" or "Amazon".
