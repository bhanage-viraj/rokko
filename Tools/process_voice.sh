#!/bin/zsh
# Dev only, not shipped. Turns ElevenLabs downloads into bundled voice files (docs/VOICE.md › Settings):
# 48 kHz mono, loudness −16 LUFS, peaks ≤ −1 dBTP, leading/trailing silence trimmed to ~40 ms, AAC .m4a.
#
#   Tools/process_voice.sh <id> <source audio file>  [<id> <file> ...]
# Output: rokko/Resources/Audio/Voice/<id>.m4a
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="rokko/Resources/Audio/Voice"
mkdir -p "$OUT"

while (( $# >= 2 )); do
  id="$1"; src="$2"; shift 2
  ffmpeg -hide_banner -loglevel error -y -i "$src" \
    -af "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.04,areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.04,areverse,loudnorm=I=-16:TP=-1:LRA=7,aresample=48000" \
    -ac 1 -c:a aac -b:a 96k -movflags +faststart "$OUT/$id.m4a"
  printf '%-26s %6.2fs\n' "$id" "$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$OUT/$id.m4a")"
done
