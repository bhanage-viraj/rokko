#!/usr/bin/env python3
"""Dev only, not shipped. Measures when the voice is actually speaking inside each subtitle line.

For every clip in Content/Lesson1/manifest.json that has subtitles, it runs ffmpeg's silencedetect
on the clip's audio and writes, for each cue, the stretches of speech inside it:

    "speech": [[4.10, 4.49], [4.95, 5.71]]     (seconds from the clip start)

The app reveals a line word by word across these stretches only, so words appear as they are said
and wait through the pauses. Also writes each clip's "endStill": the last bright frame before the
fade, shown (dimmed, with "Finished") when the clip has ended.

    python3 -I Tools/subtitle_speech_spans.py
Re-run after replacing a clip or editing subtitle times.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "rokko/Content/Lesson1"
VIDEO = ROOT / "rokko/Resources/Video"

NOISE_DB = -35      # quieter than this counts as a pause
MIN_PAUSE = 0.12    # shorter dips are breaths inside a word
MIN_SPEECH = 0.08   # drop speech slivers shorter than this
BRIGHT_SHARE = 0.9  # endStill: last frame at least this bright vs the closing scene


def mmss(s: str) -> float:
    m, x = s.split(":")
    return int(m) * 60 + float(x)


def silences(path: Path) -> list[tuple[float, float]]:
    err = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-vn",
                          "-af", f"silencedetect=noise={NOISE_DB}dB:d={MIN_PAUSE}", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([0-9.]+)", err)]
    ends = [float(x) for x in re.findall(r"silence_end: ([0-9.]+)", err)]
    ends += [float("inf")] * (len(starts) - len(ends))
    return list(zip(starts, ends))


def speech_in(a: float, b: float, quiet: list[tuple[float, float]]) -> list[list[float]]:
    spans, t = [], a
    for s, e in quiet:
        if e <= t or s >= b:
            continue
        if s > t:
            spans.append([t, min(s, b)])
        t = max(t, e)
    if t < b:
        spans.append([t, b])
    spans = [[round(x, 3), round(y, 3)] for x, y in spans if y - x >= MIN_SPEECH]
    return spans or [[round(a, 3), round(b, 3)]]


def end_still(path: Path, duration: float) -> float:
    err = subprocess.run(["ffmpeg", "-hide_banner", "-sseof", "-6", "-i", str(path), "-an",
                          "-vf", "signalstats,metadata=print:key=lavfi.signalstats.YAVG", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    ts = [float(x) for x in re.findall(r"pts_time:([0-9.]+)", err)]
    ys = [float(x) for x in re.findall(r"YAVG=([0-9.]+)", err)]
    peak = max(ys)
    last = max(t for t, y in zip(ts, ys) if y >= BRIGHT_SHARE * peak)
    return round(max(0.0, duration - 6 + last), 3)


def main() -> int:
    manifest_path = CONTENT / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    for clip in manifest["clips"]:
        sub = clip.get("subtitles")
        video = VIDEO / clip["files"]["standard"]
        if not sub or not video.exists():
            continue
        clip["endStill"] = end_still(video, clip["seconds"])
        path = CONTENT / "Subtitles" / sub
        doc = json.loads(path.read_text())
        quiet = silences(video)
        for cue in doc["cues"]:
            cue["speech"] = speech_in(mmss(cue["start"]), mmss(cue["end"]), quiet)
        path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
        print(f"{clip['id']}: {len(doc['cues'])} lines, still at {clip['endStill']}s")
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
