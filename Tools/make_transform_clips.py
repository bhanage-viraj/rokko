#!/usr/bin/env python3
# Dev only, not shipped. Renders the six Lesson 1 transformation clips (animal becomes piece),
# Standard and Calm, from the app's own art, so the clip matches the "after" screen.
#
#   python3 Tools/make_transform_clips.py            # all six
#   python3 Tools/make_transform_clips.py KING ROOK  # some
#
# Needs: python3, Pillow, numpy, ffmpeg. Output: rokko/Resources/Video/L1_TR_<PIECE>_{standard,calm}.mp4
# Standard 2.8 s: animal breathes, honey glow rises, animal warms and dissolves into the piece,
#   piece grows in with one soft settle, a few slow sparkles. No flash, no spin, no sound.
# Calm 2.4 s: plain cross-fade, nothing moves (docs/PRD.md › Sensory: fades instead of transformations).
# Durations / endStill live in Content/Lesson1/manifest.json (2.8 s, endStill 2.35).
import math, os, sys, subprocess, numpy as np
from PIL import Image, ImageFilter, ImageDraw
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
A = os.path.join(ROOT, "rokko/Assets.xcassets")
OUT = os.path.join(ROOT, "rokko/Resources/Video")
W, H, FPS = 1920, 1080, 30
PAIRS = {"KING": "lion", "QUEEN": "lioness", "ROOK": "elephant", "BISHOP": "kangaroo", "KNIGHT": "horse", "PAWN": "squirrel"}
HONEY = (226, 178, 74); PAPER = (244, 240, 227)
def clamp(v, a=0., b=1.): return max(a, min(b, v))
def ease(t): t = clamp(t); return t * t * (3 - 2 * t)
def ease_out(t): t = clamp(t); return 1 - (1 - t) ** 3
def back_out(t, k=1.3): t = clamp(t); t -= 1; return 1 + t * t * ((k + 1) * t + k)

def load(name):
    im = Image.open(f"{A}/{name}.imageset/{name}.png").convert("RGBA"); return im.crop(im.getbbox())

bgsrc = Image.open(os.path.join(ROOT, "Media/Source/transform_background_meadow.png")).convert("RGB")
def make_bg():
    b = bgsrc.resize((W, int(bgsrc.height * W / bgsrc.width)))
    if b.height < H: b = bgsrc.resize((int(bgsrc.width * H / bgsrc.height), H))
    b = b.crop(((b.width - W) // 2, (b.height - H) // 2, (b.width - W) // 2 + W, (b.height - H) // 2 + H))
    b = b.filter(ImageFilter.GaussianBlur(10))
    b = Image.blend(b, Image.new("RGB", (W, H), PAPER), 0.35)
    return b.convert("RGBA")
BG = make_bg()
FOOT = 900

def fit(im, maxw, maxh):
    s = min(maxw / im.width, maxh / im.height); return im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)

def tint(im, col, k):
    if k <= 0: return im
    a = np.asarray(im).astype(np.float32); c = np.array(col, np.float32)
    a[..., :3] = a[..., :3] * (1 - k) + c * k
    return Image.fromarray(a.astype(np.uint8))

def with_alpha(im, a):
    if a >= 1: return im
    arr = np.asarray(im).copy(); arr[..., 3] = (arr[..., 3] * clamp(a)).astype(np.uint8); return Image.fromarray(arr)

def glow(r, a):
    g = Image.new("RGBA", (r * 2, r * 2), (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    for i in range(24, 0, -1):
        rr = int(r * i / 24); d.ellipse((r - rr, r - rr, r + rr, r + rr), fill=HONEY + (int(255 * a * (1 - i / 24) ** 1.6 * 0.55),))
    return g.filter(ImageFilter.GaussianBlur(r / 10))

def shadow(w, a):
    s = Image.new("RGBA", (w, w // 5), (0, 0, 0, 0)); ImageDraw.Draw(s).ellipse((0, 0, w, w // 5), fill=(40, 50, 40, int(70 * a)))
    return s.filter(ImageFilter.GaussianBlur(10))

def spark(sz, a):
    s = Image.new("RGBA", (sz, sz), (0, 0, 0, 0)); d = ImageDraw.Draw(s); c = sz / 2; r = sz / 2
    d.polygon([(c, 0), (c + r * .22, c - r * .22), (sz, c), (c + r * .22, c + r * .22), (c, sz), (c - r * .22, c + r * .22), (0, c), (c - r * .22, c - r * .22)],
              fill=(255, 236, 180, int(255 * a)))
    return s.filter(ImageFilter.GaussianBlur(0.8))

def put(fr, im, cx, bottom, scale=1.0, alpha=1.0):
    if scale != 1.0: im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.LANCZOS)
    im = with_alpha(im, alpha); fr.alpha_composite(im, (int(cx - im.width / 2), int(bottom - im.height)))

def frames(code, calm):
    animal = fit(load(f"char_{PAIRS[code]}_ivory"), 1000, 660)
    raw = load(f"piece_{code.lower()}_ivory"); k = 720 / 416; piece = raw.resize((int(raw.width * k), int(raw.height * k)), Image.LANCZOS)
    cx = W // 2
    dur = 2.4 if calm else 2.8
    n = int(round(dur * FPS))
    rng = np.random.default_rng(sum(map(ord, code)))
    sp = [(rng.uniform(-420, 420), rng.uniform(-560, -60), rng.uniform(0.55, 1.35), rng.uniform(26, 46)) for _ in range(9)]
    for i in range(n):
        t = i / FPS; fr = BG.copy()
        if calm:
            k = ease((t - 0.5) / 1.0)                      # 0.5 → 1.5 s cross-fade
            sh = shadow(int(animal.width * .7 * (1 - k) + piece.width * 1.2 * k), 1); fr.alpha_composite(sh, (cx - sh.width // 2, FOOT - sh.height // 2))
            put(fr, animal, cx, FOOT, 1.0, 1 - k)
            put(fr, piece, cx, FOOT, 1.0, k)
        else:
            breathe = 1 + 0.012 * math.sin(t * 2 * math.pi / 1.6)
            g = ease((t - 0.25) / 0.6) * (1 - 0.55 * ease((t - 1.7) / 0.7))   # honey glow rises, then softens
            gl = glow(460, g); fr.alpha_composite(gl, (cx - 460, FOOT - 330 - 460))
            m = ease((t - 0.7) / 0.8)                       # 0.7 → 1.5 s: animal becomes the piece
            sh = shadow(int(animal.width * .7 * (1 - m) + piece.width * 1.2 * m), 1); fr.alpha_composite(sh, (cx - sh.width // 2, FOOT - sh.height // 2))
            warm = ease((t - 0.35) / 0.5) * (1 - ease((t - 1.35) / 0.55))   # both glow warm honey during the change
            if m < 1:
                a_sc = breathe * (1 - 0.25 * m)
                put(fr, tint(animal, (255, 228, 160), 0.55 * warm), cx, FOOT, a_sc, 1 - m)
            if m > 0:
                settle = back_out((t - 0.75) / 0.85, 1.1)   # gentle grow with a tiny settle, no bounce loop
                p_sc = 0.72 + 0.28 * settle
                put(fr, tint(piece, (255, 228, 160), 0.55 * warm), cx, FOOT, p_sc, m)
            for (dx, dy, st, sz) in sp:                     # slow drifting sparkles, fade in and out
                u = (t - st) / 1.1
                if 0 < u < 1:
                    a = math.sin(u * math.pi) * 0.85
                    s = spark(int(sz), a); fr.alpha_composite(s, (int(cx + dx - sz / 2), int(FOOT - 300 + dy * 0.8 - 40 * u - sz / 2)))
        yield fr.convert("RGB")

def lerp(a, b, t): return a + (b - a) * t

def render(code, calm, out):
    p = subprocess.Popen(["ffmpeg", "-nostdin", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                          "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", "-g", "30", "-movflags", "+faststart", "-an", out], stdin=subprocess.PIPE)
    for f in frames(code, calm): p.stdin.write(f.tobytes())
    p.stdin.close(); p.wait()

if __name__ == "__main__":
    for code in (sys.argv[1:] or list(PAIRS)):
        for calm in (False, True):
            render(code, calm, os.path.join(OUT, f"L1_TR_{code}_{'calm' if calm else 'standard'}.mp4")); print("done", code, calm, flush=True)
