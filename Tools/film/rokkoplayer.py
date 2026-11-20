"""RokkoPlayer: plays a character's keyframed timeline (the same tracks written into Figma) from the
full-resolution layer images. Bones pivot at their joints; keyframes use Figma's fields and easings."""
import json, math
import numpy as np
import skia

SEG = {"idle": (0.0, 3.2), "walk": (3.2, 5.4), "hop": (5.4, 6.8), "sig": (6.8, 9.0)}


def _bez(x1, y1, x2, y2):
    def f(u):
        lo, hi = 0.0, 1.0
        for _ in range(20):
            m = (lo + hi) / 2; x = 3 * (1 - m) ** 2 * m * x1 + 3 * (1 - m) * m * m * x2 + m ** 3
            lo, hi = (m, hi) if x < u else (lo, m)
        m = (lo + hi) / 2; return 3 * (1 - m) ** 2 * m * y1 + 3 * (1 - m) * m * m * y2 + m ** 3
    return f
EASE = {"LINEAR": lambda u: u, "EASE_IN_AND_OUT": _bez(.42, 0, .58, 1), "EASE_OUT": _bez(0, 0, .58, 1), "EASE_IN": _bez(.42, 0, 1, 1)}


def sample(keys, t):
    if t <= keys[0]["t"]: return keys[0]["v"]
    if t >= keys[-1]["t"]: return keys[-1]["v"]
    for a, b in zip(keys, keys[1:]):
        if a["t"] <= t <= b["t"]:
            u = (t - a["t"]) / max(1e-6, b["t"] - a["t"]); return a["v"] + (b["v"] - a["v"]) * EASE[b["e"]](u)
    return keys[-1]["v"]


def _skimg(path):
    from PIL import Image
    a = np.array(Image.open(path).convert("RGBA"))
    return skia.Image.fromarray(a, colorType=skia.ColorType.kRGBA_8888_ColorType, alphaType=skia.AlphaType.kUnpremul_AlphaType).withDefaultMipmaps()


class Character:
    def __init__(self, key, tracks_key=None, folder="parts"):
        self.rig = json.load(open(f"{folder}/{key}.rig.json"))
        self.tracks = json.load(open(f"{folder}/{tracks_key or key}.tracks.json"))
        self.layers = self.rig["layers"]
        self.by = {l["name"]: l for l in self.layers}
        self.img = {l["name"]: _skimg(f"{folder}/{key}__{l['name']}.png") for l in self.layers}
        import os
        self.closed = {}
        for l in self.layers:
            p = f"{folder}/{key}__{l['name']}_closed.png"
            if os.path.exists(p): self.closed[l["name"]] = _skimg(p)

    def pose(self, t, extra=None):
        """Bone values at timeline time t; extra adds degrees (Figma sense, CCW +) to bone rotations."""
        P = {}
        for b, fs in self.tracks.items():
            P[b] = {f: sample(k, t) for f, k in fs.items()}
        for b, v in (extra or {}).items():
            P.setdefault(b, {}); P[b]["ROTATION"] = P[b].get("ROTATION", 0.0) + v
        return P

    def world(self, P):
        M = {}
        for l in self.layers:                     # layers are in z order; parents come before... resolve recursively
            self._mat(l["name"], P, M)
        return M

    def _mat(self, n, P, M):
        if n in M: return M[n]
        l = self.by[n]; px, py = l["pivot"]; v = P.get(n, {})
        L = skia.Matrix()
        L.preTranslate(v.get("TRANSLATION_X", 0.0), v.get("TRANSLATION_Y", 0.0))
        L.preTranslate(px, py); L.preRotate(-v.get("ROTATION", 0.0)); L.preScale(v.get("SCALE_X", 1.0), v.get("SCALE_Y", 1.0)); L.preTranslate(-px, -py)
        M[n] = skia.Matrix.Concat(self._mat(l["parent"], P, M), L) if l["parent"] else L
        return M[n]

    def render(self, t, s, crop, pad, extra=None, blink=False):
        """RGBA uint8 of the character at timeline time t, scale s, cropped to crop (full-frame box) + pad px."""
        x0, y0, x1, y1 = crop
        W = max(2, int(round((x1 - x0) * s)) + 2 * pad); H = max(2, int(round((y1 - y0) * s)) + 2 * pad)
        surf = skia.Surface(W, H); cv = surf.getCanvas(); cv.clear(skia.ColorTRANSPARENT)
        cv.translate(pad, pad); cv.scale(s, s); cv.translate(-x0, -y0)
        M = self.world(self.pose(t, extra))
        paint = skia.Paint(AntiAlias=True)
        samp = skia.SamplingOptions(skia.FilterMode.kLinear, skia.MipmapMode.kLinear)
        for l in self.layers:
            im = self.closed.get(l["name"]) if (blink and l["name"] in self.closed) else self.img[l["name"]]
            cv.save(); cv.concat(M[l["name"]]); cv.drawImage(im, l["x"], l["y"], samp, paint); cv.restore()
        return surf.makeImageSnapshot().toarray(colorType=skia.ColorType.kRGBA_8888_ColorType, alphaType=skia.AlphaType.kUnpremul_AlphaType)
