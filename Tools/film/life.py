"""Living scenery for the film: wind in the leaves, drifting pollen, soft light rays, butterflies, falling leaves.
Everything is slow and soft (no flashes, nothing fast), deterministic from the film time so frames render in any order."""
import math
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFilter

W, H = 1920, 1080
_masks = {}

def foliage_mask(name, img):
    """Where the picture is plants (green-ish, textured): 0..1, soft. Ground band and sky move less."""
    if name not in _masks:
        a = np.asarray(img.convert("RGB")).astype(np.float32) / 255
        hsv = cv2.cvtColor((a * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
        hue, sat, val = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
        green = np.clip((sat - 0.12) / 0.2, 0, 1) * ((hue > 55) & (hue < 190)).astype(np.float32)
        tex = cv2.GaussianBlur(np.abs(cv2.Laplacian(cv2.cvtColor((a * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY), cv2.CV_32F)), (0, 0), 6)
        tex = np.clip(tex / 6, 0, 1)
        m = cv2.GaussianBlur(green * (0.35 + 0.65 * tex), (0, 0), 9)
        _masks[name] = np.clip(m * 1.6, 0, 1).astype(np.float32)
    return _masks[name]

_grid = None
def wind(name, img, T, strength=1.0):
    """Sway the plants of a background: travelling gusts, more at the top of plants, never the ground line."""
    global _grid
    if _grid is None:
        X, Y = np.meshgrid(np.arange(W, dtype=np.float32), np.arange(H, dtype=np.float32)); _grid = (X, Y)
    X, Y = _grid
    m = foliage_mask(name, img)
    gust = 0.6 + 0.4 * math.sin(T * 0.23)                       # slow breathing of the wind
    ph = T * 1.25 - X / 380.0 + 0.7 * np.sin(Y / 140.0)
    dx = (3.2 * np.sin(ph) + 1.2 * np.sin(T * 2.1 - X / 150.0 + Y / 90.0)) * gust * strength * m
    dy = 0.8 * np.sin(ph * 1.3 + 1.0) * gust * strength * m
    out = cv2.remap(np.asarray(img), X - dx, Y - dy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    return Image.fromarray(out)

# ------------------------------------------------------------------ overlays (made once)
def _rays():
    r = Image.new("L", (W, H), 0); d = ImageDraw.Draw(r)
    for k, (x0, wdt) in enumerate(((180, 160), (520, 110), (860, 190), (1250, 120))):
        d.polygon([(x0, -40), (x0 + wdt, -40), (x0 + wdt + 620, H), (x0 + 620 - wdt * 0.4, H)], fill=150 - 25 * k)
    r = r.filter(ImageFilter.GaussianBlur(60))
    g = np.linspace(1.0, 0.15, H, dtype=np.float32)[:, None]   # fade toward the ground
    return (np.asarray(r).astype(np.float32) / 255) * g
RAYS = _rays()

def _vignette():
    X, Y = np.meshgrid(np.linspace(-1, 1, W), np.linspace(-1, 1, H))
    v = np.clip((np.sqrt((X * 0.85) ** 2 + Y ** 2) - 0.55) / 0.75, 0, 1) ** 1.6
    return (v * 0.32).astype(np.float32)
VIG = _vignette()

def _mote(r):
    a = Image.new("L", (r * 4, r * 4), 0)
    ImageDraw.Draw(a).ellipse([r, r, r * 3, r * 3], fill=255)
    s = Image.new("RGBA", a.size, (255, 246, 210, 0)); s.putalpha(a.filter(ImageFilter.GaussianBlur(r * 0.7)))
    return s
MOTES = [_mote(r) for r in (3, 5, 8)]

def _leaf(col):
    s = Image.new("RGBA", (60, 34), (0, 0, 0, 0)); d = ImageDraw.Draw(s)
    d.ellipse([2, 4, 58, 30], fill=col + (255,), outline=(70, 60, 40, 255), width=2)
    d.line([(4, 17), (56, 17)], fill=(70, 60, 40, 200), width=2)
    return s
LEAVES = [_leaf((122, 160, 90)), _leaf((196, 168, 92)), _leaf((150, 178, 110))]

def _wing(col):
    s = Image.new("RGBA", (60, 60), (0, 0, 0, 0)); d = ImageDraw.Draw(s)
    d.ellipse([4, 2, 56, 40], fill=col + (255,), outline=(90, 60, 40, 255), width=3)
    d.ellipse([10, 30, 44, 58], fill=tuple(int(c * 0.92) for c in col) + (255,), outline=(90, 60, 40, 255), width=3)
    return s
WINGS = [_wing((246, 196, 92)), _wing((236, 170, 140))]

def _rng(seed): return np.random.default_rng(seed)
_MP = _rng(7).uniform(0, 1, (34, 6))                              # pollen: x, y, speed, size, phase, depth

def _paste(fr, spr, x, y, a=1.0):
    if a < 0.999:
        spr = spr.copy(); spr.putalpha(spr.getchannel("A").point(lambda v: int(v * a)))
    x0, y0 = int(x - spr.width / 2), int(y - spr.height / 2)
    if x0 > W or y0 > H or x0 + spr.width < 0 or y0 + spr.height < 0: return
    cx0, cy0 = max(0, -x0), max(0, -y0); cx1, cy1 = min(spr.width, W - x0), min(spr.height, H - y0)
    fr.alpha_composite(spr.crop((cx0, cy0, cx1, cy1)), (x0 + cx0, y0 + cy0))

def butterfly(fr, T, k):
    """One butterfly on a slow looping path through the upper half; wings flap ~3 times a second."""
    u = T * 0.045 + k * 0.37
    side = k % 2                                               # one stays left, one right
    x = W * (0.27 + 0.46 * side + 0.2 * math.sin(2 * math.pi * u + k)) + 40 * math.sin(T * 0.9 + k)
    y = H * (0.30 + 0.12 * math.sin(2 * math.pi * u * 2.0 + k * 1.7)) + 18 * math.sin(T * 2.3 + k)
    flap = abs(math.cos(T * 2 * math.pi * 3.0 + k))
    wing = WINGS[k % 2]
    sc = 0.85
    ww = max(2, int(wing.width * sc * (0.25 + 0.75 * flap))); wh = int(wing.height * sc)
    wR = wing.resize((ww, wh), Image.BILINEAR); wL = wR.transpose(Image.FLIP_LEFT_RIGHT)
    dirx = math.cos(2 * math.pi * u + k)                       # facing the way it flies
    _paste(fr, wL, x - ww / 2, y)
    _paste(fr, wR, x + ww / 2, y)
    d = ImageDraw.Draw(fr); d.line([(x, y - wh * 0.45), (x, y + wh * 0.4)], fill=(80, 55, 40, 255), width=4)

def falling_leaves(fr, T, n=2):
    for k in range(n):
        period = 13.0 + 3 * k
        u = ((T + k * 6.1) % period) / period
        x = W * (0.15 + 0.7 * ((k * 0.61 + math.floor((T + k * 6.1) / period) * 0.37) % 1)) + 90 * math.sin(u * 2 * math.pi * 1.5 + k)
        y = -40 + (H + 80) * u
        ang = 35 * math.sin(u * 2 * math.pi * 1.5 + k)
        lf = LEAVES[k % 3].resize((44, 25), Image.BILINEAR).rotate(ang, resample=Image.BICUBIC, expand=True)
        _paste(fr, lf, x, y, 0.9)

def pollen(fr, T):
    for x0, y0, sp, sz, ph, dep in _MP:
        x = (x0 * W + T * (8 + 22 * sp) + 30 * math.sin(T * 0.5 + ph * 6)) % (W + 60) - 30
        y = (y0 * H - T * (5 + 12 * sp) + 20 * math.sin(T * 0.7 + ph * 9)) % (H + 60) - 30
        a = (0.25 + 0.35 * dep) * (0.6 + 0.4 * math.sin(T * 0.8 + ph * 7))
        _paste(fr, MOTES[int(sz * 2.99)], x, y, a)

def light(fr, T, amount=1.0):
    """Soft warm rays that slowly shift, then a gentle vignette. Works on the RGBA frame in place."""
    a = np.asarray(fr).astype(np.float32)
    shift = int(40 * math.sin(T * 0.11))
    rays = np.roll(RAYS, shift, axis=1) * (0.75 + 0.25 * math.sin(T * 0.37)) * 0.16 * amount
    warm = np.array([255, 240, 200], np.float32)
    a[..., :3] = a[..., :3] + (warm - a[..., :3]) * rays[..., None]
    a[..., :3] *= (1 - VIG[..., None])
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
