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


GRID = 9


class LayerMesh:
    """A layer drawn as a skinned triangle mesh (bends smoothly: elephant ear and trunk), so no piece is cut."""
    def __init__(self, layer, img_rgba, bones):
        import cv2
        h, w = img_rgba.shape[:2]; X0, Y0 = layer["x"], layer["y"]
        a = cv2.dilate((img_rgba[..., 3] > 8).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        gx = np.arange(0, w + GRID, GRID); gy = np.arange(0, h + GRID, GRID); nx, ny = len(gx), len(gy)
        cell = np.zeros((ny - 1, nx - 1), bool)
        for j in range(ny - 1):
            for i in range(nx - 1):
                cell[j, i] = a[gy[j]:min(h, gy[j + 1]), gx[i]:min(w, gx[i + 1])].any()
        used = np.zeros((ny, nx), bool)
        used[:-1, :-1] |= cell; used[1:, :-1] |= cell; used[:-1, 1:] |= cell; used[1:, 1:] |= cell
        vid = -np.ones((ny, nx), int); vid[used] = np.arange(used.sum())
        VX, VY = np.meshgrid(gx, gy)
        self.T = np.stack([VX[used], VY[used]], 1).astype(np.float32)               # texture coords (layer px)
        self.V = self.T + np.array([X0, Y0], np.float32)                              # rest positions (frame px)
        idx = []
        for j in range(ny - 1):
            for i in range(nx - 1):
                if cell[j, i]:
                    q = vid[j, i], vid[j, i + 1], vid[j + 1, i], vid[j + 1, i + 1]; idx += [q[0], q[1], q[2], q[1], q[3], q[2]]
        self.idx = [int(v) for v in idx]
        self.tex = [skia.Point(float(x), float(y)) for x, y in self.T]
        # envelope weights (nearest bone wins softly; the head itself owns everything else)
        s = 0.02 * 1024 * 1.414
        logits = [np.full(len(self.V), -9.0)]
        self.bones = bones
        for name, parent, p, e, r, box in bones:
            P = np.array(p) * 1024; E = np.array(e) * 1024; v = E - P
            u = np.clip(((self.V - P) @ v) / (v @ v), 0, 1)
            d = np.linalg.norm(self.V - (P + u[:, None] * v), axis=1)
            d = np.maximum(0, d - r * 1024 * 1.414)
            fx, fy = self.V[:, 0] / 1024, self.V[:, 1] / 1024
            inside = (fx >= box[0]) & (fy >= box[1]) & (fx <= box[2]) & (fy <= box[3])
            logits.append(-(d / s) ** 2 - 60.0 * (~inside))
        L = np.stack(logits, 1); L -= L.max(1, keepdims=True); E_ = np.exp(L)
        self.W = (E_ / E_.sum(1, keepdims=True)).astype(np.float32)

    def deform(self, rot):
        """rot: {bone: Figma degrees (CCW +)} -> moved vertices (frame px)."""
        mats = [np.eye(3)]; world = {}
        for name, parent, p, e, r, box in self.bones:
            th = math.radians(-rot.get(name, 0.0)); c, s_ = math.cos(th), math.sin(th)
            px, py = p[0] * 1024, p[1] * 1024
            M = np.array([[c, -s_, px - c * px + s_ * py], [s_, c, py - s_ * px - c * py], [0, 0, 1]])
            if parent: M = world[parent] @ M
            world[name] = M; mats.append(M)
        A = np.stack([m[:2, :2] for m in mats]); Tt = np.stack([m[:2, 2] for m in mats])
        P = np.einsum("mij,vj->vmi", A, self.V) + Tt[None]
        return np.einsum("vm,vmi->vi", self.W, P)


class Character:
    def __init__(self, key, tracks_key=None, folder="parts"):
        self.rig = json.load(open(f"{folder}/{key}.rig.json"))
        self.tracks = json.load(open(f"{folder}/{tracks_key or key}.tracks.json"))
        self.layers = self.rig["layers"]
        self.by = {l["name"]: l for l in self.layers}
        self.img = {l["name"]: _skimg(f"{folder}/{key}__{l['name']}.png") for l in self.layers}
        import os
        from PIL import Image as _I
        self.meshes = {}
        try:
            import elemesh
            if key in elemesh.MESH:
                l = self.by["head"]; arr = np.array(_I.open(f"{folder}/{key}__head.png").convert("RGBA"))
                self.meshes["head"] = LayerMesh(l, arr, elemesh.MESH[key])
        except ImportError:
            pass
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
        self._last_pose = self.pose(t, extra)
        M = self.world(self._last_pose)
        paint = skia.Paint(AntiAlias=True)
        samp = skia.SamplingOptions(skia.FilterMode.kLinear, skia.MipmapMode.kLinear)
        for l in self.layers:
            im = self.closed.get(l["name"]) if (blink and l["name"] in self.closed) else self.img[l["name"]]
            cv.save(); cv.concat(M[l["name"]])
            mesh = self.meshes.get(l["name"])
            if mesh is None:
                cv.drawImage(im, l["x"], l["y"], samp, paint)
            else:
                Pz = self._last_pose
                Vd = mesh.deform({b[0]: Pz.get(b[0], {}).get("ROTATION", 0.0) for b in mesh.bones})
                mp = skia.Paint(AntiAlias=True)
                mp.setShader(im.makeShader(skia.TileMode.kDecal, skia.TileMode.kDecal, samp))
                v = skia.Vertices.MakeCopy(skia.Vertices.kTriangles_VertexMode, [skia.Point(float(x), float(y)) for x, y in Vd], mesh.tex, None, mesh.idx)
                cv.translate(0, 0); cv.drawVertices(v, mp)
            cv.restore()
        return surf.makeImageSnapshot().toarray(colorType=skia.ColorType.kRGBA_8888_ColorType, alphaType=skia.AlphaType.kUnpremul_AlphaType)
