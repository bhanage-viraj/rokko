#!/bin/zsh
# Dev only, not shipped. Cuts the Lesson 1 film into its 8 clips (re-encoded, frame-accurate).
# Every cut sits on a fade-to-dark between scenes. v6 (19 Nov): 24 fps, keyframed layer rigs from the original art + living scenery, same scene times as v2,
# so the subtitle files stay valid.
#
#   Tools/cut_lesson1_film.sh [source.mp4]
#
# Source default: Media/Source/Lesson1_The_Day_the_Jungle_Changed_v6.mp4
# Output:         rokko/Resources/Video/L1_<nn>_<name>.mp4 (ids match Content/Lesson1/manifest.json)
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:-Media/Source/Lesson1_The_Day_the_Jungle_Changed_v6.mp4}"
OUT="rokko/Resources/Video"
mkdir -p "$OUT"

# name  start  end   (seconds in the source)
CLIPS=(
  "01_story      0.000   76.554"
  "02_kings     76.554  114.060"
  "03_queens   114.060  131.143"
  "04_elephants 131.143 147.643"
  "05_kangaroos 147.643 161.940"
  "06_horses   161.940  176.292"
  "07_squirrels 176.292 200.447"
  "08_ending   200.447  216.982"
)

for row in "${CLIPS[@]}"; do
  read -r name start end <<< "$row"
  dur=$(printf '%.3f' $(( end - start )))
  echo "L1_${name}: ${start}s → ${end}s (${dur}s)"
  # -ss before -i with a re-encode is frame-accurate; -t is the clip length.
  ffmpeg -hide_banner -loglevel error -y \
    -ss "$start" -i "$SRC" -t "$dur" \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -r 24 -g 48 \
    -c:a aac -b:a 128k -ar 44100 -ac 1 \
    -movflags +faststart \
    "$OUT/L1_${name}.mp4"
done
