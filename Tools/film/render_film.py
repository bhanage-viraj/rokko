"""Lesson 1: The Day the Jungle Changed — full cut-out animation, 12 fps, 1920x1080.
Usage: python3 render.py <part_index> <num_parts>   (renders a slice of frames to parts/part_k.mp4)
       python3 render.py audio                      (writes the mixed soundtrack)
       python3 render.py still <seconds>            (writes one frame to still.png)"""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, FPS, SR = 1920, 1080, 24, 44100
U = "/mnt/user-data/uploads/"
DL = "/mnt/user-data/uploads/Downloads/"
HERE = os.path.dirname(os.path.abspath(__file__))
FONT_B = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
FONT_M = "/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf"
DURS = json.load(open(f"{HERE}/clips/durs.json"))

# ------------------------------------------------------------------ helpers
def clamp(v, a=0.0, b=1.0): return max(a, min(b, v))
def ease(t): t = clamp(t); return t * t * (3 - 2 * t)
def ease_out(t): t = clamp(t); return 1 - (1 - t) ** 3
def lerp(a, b, t): return a + (b - a) * t

def cover(img, w=W, h=H):
    s = max(w / img.width, h / img.height)
    im = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))

_bg = {}
def bg(name):
    if name not in _bg:
        paths = {"clearing": U + "94ae00db-image.jpg", "trees": U + "66058fe6-image.png", "meadow": U + "314f33d1-image.png",
                 "stage": U + "3565897a-image.png", "stones": U + "1853c04a-image.png", "leafy": U + "287d1ca0-image.png",
                 "leafy2": U + "9e04d130-image.png", "board": U + "8e44fa53-image.png",
                 "river": DL + "Agent Image - Place the cream elephant _first character reference_ and the charcoal-grey elephant _s.png",
                 "ponies": DL + "Agent Image - Place the cream pony _first character reference_ and the charcoal-grey pony _second ch.png"}
        _bg[name] = cover(Image.open(paths[name]).convert("RGB")).convert("RGBA")
    return _bg[name]

T_NOW = [0.0]
def bg_live(name):
    """The background with wind in its plants (life.py), at the current film time."""
    return LIFE.wind(name, bg(name), T_NOW[0], 0.6 if name in ("board", "leafy2") else 1.0)

_props = {}
def prop(name):
    if name not in _props:
        _props[name] = Image.open(f"{HERE}/props/{name}.png").convert("RGBA")
    return _props[name]

# ------------------------------------------------------------------ characters
CHAR_FILES = {"lion_c": "16ae800e", "lion_d": "de5b3947", "queen_c": "53e2382c", "queen_d": "cb2fdc59",
              "ele_c": "de22a48b", "ele_d": "90347116", "roo_c": "90ffaa13", "roo_d": "32d63e92",
              "horse_c": "8f9b5f5c", "horse_d": "c61e1a42", "sq_c": "9c31034c", "sq_d": "eebea89b"}

import cv2
import rokkorig as RR
import rokkoplayer as RP
import life as LIFE
EYES = json.load(open(f"{HERE}/eyes.json"))
# fractions of the cropped sprite: tail pivot + region, head pivot + region type
PARAMS = {
 "lion":  dict(tail=(0.27, 0.72, 0.0), head=(0.55, 0.62, "top", 0.40)),
 "queen": dict(tail=(0.33, 0.45, 0.0), head=(0.79, 0.40, "top", 0.62)),
 "ele":   dict(tail=(0.12, 0.45, 0.0), head=(0.84, 0.56, "trunk", 0.80)),
 "roo":   dict(tail=(0.36, 0.83, 0.55), head=(0.80, 0.37, "top", 0.0)),
 "horse": dict(tail=(0.27, 0.46, 0.0), head=(0.75, 0.33, "top", 0.45)),
 "sq":    dict(tail=(0.47, 0.90, 0.0), head=(0.73, 0.57, "top", 0.50)),
}

def close_eye(img_rgba, eye):
    a = np.array(img_rgba)
    x, y, w, h = eye
    rgb = cv2.cvtColor(a[..., :3].copy(), cv2.COLOR_RGB2BGR)
    m = np.zeros(rgb.shape[:2], np.uint8)
    cx, cy = x + w / 2, y + h / 2
    cv2.ellipse(m, (int(cx), int(cy)), (int(w * 0.72), int(h * 0.72)), 0, 0, 360, 255, -1)
    f = cv2.inpaint(rgb, m, 9, cv2.INPAINT_TELEA)
    a[..., :3] = cv2.cvtColor(f, cv2.COLOR_BGR2RGB)
    im = Image.fromarray(a); d = ImageDraw.Draw(im)
    lw = max(4, int(w * 0.11))
    d.arc([cx - w * 0.55, cy - h * 0.45, cx + w * 0.55, cy + h * 0.45], start=15, end=165, fill=(60, 30, 22, 255), width=lw)
    d.line([(cx - w * 0.5, cy + h * 0.12), (cx - w * 0.68, cy + h * 0.22)], fill=(60, 30, 22, 255), width=max(3, lw - 2))
    return im

class Char:
    def __init__(self, key):
        im = Image.open(U + CHAR_FILES[key] + "-image.png").convert("RGBA")
        a = np.array(im)
        a[a[..., 3] < 20] = 0
        im = Image.fromarray(a)
        self.key = key
        self.full = im
        self.bbox = im.getbbox()
        self.img = im.crop(self.bbox)
        eyes = EYES.get(key) or []
        if eyes:
            ex, ey, ew, eh = eyes[0]
            self.img_closed = close_eye(self.img, (ex - self.bbox[0], ey - self.bbox[1], ew, eh))
        else:
            self.img_closed = self.img
        self.w, self.h = self.img.size
        self.P = PARAMS[key.split("_")[0]]
        al = np.array(self.img)[..., 3]
        rows = np.where(al.max(1) > 0)[0]
        top = rows[0]
        band = al[top: top + max(12, int(self.h * 0.07))]
        xs = np.where(band.max(0) > 0)[0]
        self.acc = (float(xs.mean()), float(top + band.shape[0] / 2))
        self.cache = {}

    def sprite(self, scale, closed=False):
        k = (round(scale, 3), closed)
        if k not in self.cache:
            src = self.img_closed if closed else self.img
            s = src.resize((max(1, round(self.w * scale)), max(1, round(self.h * scale))), Image.LANCZOS)
            if len(self.cache) > 80: self.cache.clear()
            self.cache[k] = s
        return self.cache[k]

_grid = {}
def warp(spr, P, tail_deg, head_deg, use_tail=True):
    w, h = spr.size
    if w < 8 or h < 8: return spr
    if (w, h) not in _grid:
        X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
        _grid[(w, h)] = (X, Y)
        if len(_grid) > 400: _grid.clear(); _grid[(w, h)] = (X, Y)
    X, Y = _grid[(w, h)]
    mx, my = X.copy(), Y.copy()
    if use_tail and abs(tail_deg) > 0.05:
        tx, ty, ymin = P["tail"]; xt, yt = tx * w, ty * h
        wt = np.clip((xt - X) / (0.55 * xt + 1), 0, 1)
        if ymin: wt = wt * np.clip((Y - ymin * h) / (0.08 * h), 0, 1)
        a = math.radians(tail_deg) * wt
        mx += (Y - yt) * a; my -= (X - xt) * a
    if abs(head_deg) > 0.05:
        hx, hy, kind, xmin = P["head"]; xn, yn = hx * w, hy * h
        if kind == "trunk":
            wh = np.clip((X - xmin * w) / (0.07 * w), 0, 1) * np.clip((Y - 0.5 * h) / (0.1 * h), 0, 1)
        else:
            wh = np.clip((yn - Y) / (0.12 * h), 0, 1) * np.clip((X - xmin * w) / (0.08 * w), 0, 1)
        b = math.radians(head_deg) * wh
        mx += (Y - yn) * b; my -= (X - xn) * b
    out = cv2.remap(np.array(spr), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
    return Image.fromarray(out)

C = {k: Char(k) for k in CHAR_FILES}

# --- elephant leg rig (cream elephant only)
_ele = np.array(C["ele_c"].full)
CUT_Y, OVER, PIV_Y = 735, 20, 725
_body = _ele.copy(); _body[CUT_Y:] = 0
_tail = np.zeros_like(_ele); _tail[420:760, 55:148] = _ele[420:760, 55:148]; _body[420:760, 55:148] = 0
def _cols(x0, x1):
    l = np.zeros_like(_ele); l[CUT_Y - OVER:880, x0:x1] = _ele[CUT_Y - OVER:880, x0:x1]; return Image.fromarray(l)
LEGS = {"nb": (_cols(170, 336), (253, PIV_Y)), "fb": (_cols(336, 495), (415, PIV_Y)),
        "nf": (_cols(495, 641), (568, PIV_Y)), "ff": (_cols(641, 775), (700, PIV_Y))}
BODY, TAIL = Image.fromarray(_body), Image.fromarray(_tail)

def ele_rig(swing, lift_nf=0.0, tail_ang=0.0):
    ang = {"nb": swing, "ff": swing, "fb": -swing, "nf": -swing}
    if lift_nf: ang["nf"] = -14 * lift_nf
    c = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    def leg(n):
        p, piv = LEGS[n]
        r = p.rotate(ang[n], resample=Image.BICUBIC, center=piv)
        dy = -int(70 * lift_nf) if (n == "nf" and lift_nf) else 0
        c.alpha_composite(r, (0, dy)) if dy == 0 else c.alpha_composite(r.crop((0, -dy, 1024, 1024)), (0, 0))
    leg("fb"); leg("ff")
    c.alpha_composite(TAIL.rotate(tail_ang, resample=Image.BICUBIC, center=(150, 440)))
    c.alpha_composite(BODY)
    leg("nb"); leg("nf")
    return c.crop(C["ele_c"].bbox)


# ---------------------------------------------------------------- leg rigs (cut-out puppets)
# per character: leg columns (x0, x1) in original 1024 image coords, the belly cut line, and which leg it is
# nb = near back, fb = far back, nf = near front, ff = far front
LEG_RIGS = {
 "lion_c":  [(266, 350, 770, "nb"), (350, 470, 770, "fb"), (566, 664, 790, "nf"), (664, 760, 790, "ff")],
 "lion_d":  [(256, 348, 775, "nb"), (348, 466, 775, "fb"), (566, 664, 800, "nf"), (664, 766, 800, "ff")],
 "queen_c": [(348, 414, 715, "nb"), (414, 508, 715, "fb"), (604, 678, 700, "nf"), (678, 760, 700, "ff")],
 "queen_d": [(335, 398, 720, "nb"), (398, 503, 720, "fb"), (604, 690, 705, "nf"), (690, 765, 705, "ff")],
 "horse_c": [(271, 352, 690, "nb"), (352, 450, 690, "fb"), (578, 660, 680, "nf"), (660, 746, 680, "ff")],
 "horse_d": [(275, 350, 720, "nb"), (350, 450, 720, "fb"), (604, 680, 705, "nf"), (680, 760, 705, "ff")],
 "ele_c":   [(170, 336, 735, "nb"), (336, 495, 735, "fb"), (495, 641, 735, "nf"), (641, 775, 735, "ff")],
 "ele_d":   [(185, 340, 755, "nb"), (340, 494, 755, "fb"), (494, 645, 755, "nf"), (645, 765, 755, "ff")],
}
RIG_OVER = 22
_rigbase = {}
_owner_maps = {}
def _rig_parts(key):
    """Split body / four legs. Each leg is traced as a connected shape (not a straight column), so slivers of the
    neighbouring leg and the hanging tail stay where they belong; the tail (skeleton weights) always stays on the body."""
    if key in _rigbase: return _rigbase[key]
    ch = C[key]; bx0, by0, bx1, by1 = ch.bbox
    op = np.array(ch.full); cl = np.array(ch.full)
    if ch.img_closed is not ch.img:
        cl[by0:by1, bx0:bx1] = np.array(ch.img_closed)
    rig = LEG_RIGS[key]
    Hh, Ww = op.shape[:2]
    Y, X = np.mgrid[0:Hh, 0:Ww]
    colid = np.full((Hh, Ww), -1, np.int32); cutmap = np.full((Hh, Ww), 10 ** 6, np.int32)
    for i, (x0, x1, cut, kind) in enumerate(rig):
        colid[:, x0:x1] = i; cutmap[:, x0:x1] = cut
    sk = RR.Skin(key.split("_")[0], Ww, Hh)                 # full-frame skeleton weights
    tail = sum(sk.W[j] for j, n in enumerate(sk.names) if n.startswith("tail")) if any(n.startswith("tail") for n in sk.names) else 0
    M = (op[..., 3] > 20) & (Y >= cutmap) & (colid >= 0) & ~(np.asarray(tail) > 0.35)
    nlab, lab = cv2.connectedComponents(M.astype(np.uint8), connectivity=8)
    owner = np.full((Hh, Ww), -1, np.int32)
    for c in range(1, nlab):
        m = lab == c
        ids, cnt = np.unique(colid[m], return_counts=True)
        if cnt.max() >= 0.7 * cnt.sum(): owner[m] = ids[cnt.argmax()]
        else: owner[m] = colid[m]
    _owner_maps[key] = owner
    legs = []
    body_o, body_c = op.copy(), cl.copy()
    for i, (x0, x1, cut, kind) in enumerate(rig):
        mine = owner == i
        xs = np.where(mine.any(0))[0]
        lx0, lx1 = (min(x0, xs.min()), max(x1, xs.max() + 1)) if len(xs) else (x0, x1)
        top = cut - RIG_OVER
        piece = np.zeros((Hh - top, lx1 - lx0, 4), np.uint8)
        sub = op[top:, lx0:lx1].copy()
        keep = mine[top:, lx0:lx1].copy()
        keep[:RIG_OVER, max(0, x0 - lx0):x1 - lx0] = True        # hip overlap (stays drawn on the body too)
        keep[:RIG_OVER] &= (np.asarray(tail)[top:top + RIG_OVER, lx0:lx1] <= 0.35) if np.ndim(tail) else True
        piece[keep] = sub[keep]
        body_o[mine] = 0; body_c[mine] = 0
        legs.append((kind, lx0, top, Image.fromarray(piece)))
    crop = lambda a: Image.fromarray(a).crop(ch.bbox)
    _rigbase[key] = (crop(body_o), crop(body_c), legs)
    return _rigbase[key]

_meshes = {}
def mesh_char(key):
    """RokkoMesh for a character: the whole picture as one textured mesh, legs traced as shapes for their bones."""
    if key in _meshes: return _meshes[key]
    import rokkomesh as RM
    ch = C[key]; bx0, by0, bx1, by1 = ch.bbox
    op = np.array(ch.full); cl = np.array(ch.full)
    if ch.img_closed is not ch.img: cl[by0:by1, bx0:bx1] = np.array(ch.img_closed)
    legs = []
    if key in LEG_RIGS:
        _rig_parts(key)                                          # computes the traced leg ownership
        owner = _owner_maps[key]
        for i, (x0, x1, cut, kind) in enumerate(LEG_RIGS[key]):
            m = owner == i
            if not m.any(): continue
            ys, xs = np.where(m)
            top = ys.min(); bot = ys.max()
            hip = (float(xs[ys < top + 30].mean()), float(cut - 8))
            legs.append((kind, m, hip, hip[1] + 0.5 * (bot - hip[1])))
    _meshes[key] = RM.MeshChar(key.split("_")[0], op, cl, legs)
    return _meshes[key]

_rigcache = {}
_legskins = {}
def leg_angles(kind, wph, lift, hop):
    """Thigh + knee angles for one leg layer: walk cycle (keyframed stride), leap (hop phase 0..1), paw / stomp (lift)."""
    th = kn = 0.0; front = kind in ("nf", "ff")
    if wph is not None:
        th, kn = RR.leg_pose(1 if kind in ("nb", "ff") else -1, wph)
    if hop is not None:
        ph, v = hop
        if ph == "crouch": kn += 14 * v; th += (-6 if front else 8) * v
        elif ph == "air":
            k = math.sin(v * math.pi)
            if front: th += -22 * k; kn += 60 * k        # front legs tuck up
            else: th += 24 * k; kn += 12 * k           # hind legs stretch back
        elif ph == "land": kn += 16 * math.sin(v * math.pi)
    if kind == "nf" and lift: th += -18 * lift; kn += 48 * lift
    return th, kn

def rig_sprite(key, s, wph=None, lift=0.0, closed=False, hop=None, pad=0, body_xform=None):
    """Body + four leg layers; every leg has a thigh and a shin bone (bends at the knee), hips blend under the body."""
    ch = C[key]; bx0, by0 = ch.bbox[0], ch.bbox[1]
    k = (key, s, closed)
    if k not in _rigcache:
        bo, bc, legs = _rig_parts(key)
        W_, H_ = max(1, round(ch.w * s)), max(1, round(ch.h * s))
        body = (bc if closed else bo).resize((W_, H_), Image.LANCZOS)
        L = []
        for idx, (kind, x0, y0, piece) in enumerate(legs):
            pw, ph = max(1, round(piece.width * s)), max(1, round(piece.height * s))
            pad = int(pw * 0.9) + 4
            p = Image.new("RGBA", (pw + 2 * pad, ph + pad), (0, 0, 0, 0))
            p.alpha_composite(piece.resize((pw, ph), Image.LANCZOS), (pad, 0))
            # the leg's real bottom (feet) inside the piece
            al = np.asarray(p)[..., 3]; rows = np.where(al.max(1) > 40)[0]; foot_y = rows[-1] if len(rows) else p.height
            hip = (pad + pw / 2, RIG_OVER * s * 0.6)
            L.append((kind, (x0 - bx0) * s - pad, (y0 - by0) * s, p, hip, hip[1] + 0.5 * (foot_y - hip[1])))
        if len(_rigcache) > 120: _rigcache.clear()
        _rigcache[k] = (body, L)
    body, L = _rigcache[k]
    out = Image.new("RGBA", (body.width + 2 * pad, body.height + 2 * pad), (0, 0, 0, 0))
    bl = Image.new("RGBA", out.size, (0, 0, 0, 0)); bl.paste(body, (pad, pad))
    if body_xform is not None: bl = body_xform(bl)        # the skeleton bends the body layer only
    def leg(item):
        kind, ox, oy, p, hip, knee_y = item
        th, kn = leg_angles(kind, wph, lift, hop)
        dy = -int(0.05 * ch.h * s * lift) if (kind == "nf" and lift) else 0
        if abs(th) > 0.05 or abs(kn) > 0.05:
            sk_k = (key, s, kind, p.size)
            sk = _legskins.get(sk_k)
            if sk is None:
                if len(_legskins) > 400: _legskins.clear()
                sk = _legskins[sk_k] = RR.LegSkin(p.width, p.height, hip, knee_y)
            r = Image.fromarray(RR.deform(np.array(p), sk, {"thigh": (th, 1, 1), "shin": (kn, 1, 1)}, iters=2))
        else:
            r = p
        _safe_paste(out, r, int(round(ox)) + pad, int(round(oy)) + dy + pad)
    for it in L:
        if it[0] in ("fb", "ff"): leg(it)
    out.alpha_composite(bl)
    for it in L:
        if it[0] in ("nb", "nf"): leg(it)
    return out


# ---------------------------------------------------------------- drawn scroll (replaces the generated scroll image)
_scroll_cache = {}
def scroll_sprite(unroll, sc):
    """unroll 0 = rolled up with a ribbon, 1 = fully open showing the 8x8 board. sc = on-screen scale (1 = 640 px wide)."""
    key = (round(unroll, 2), round(sc, 2))
    if key in _scroll_cache: return _scroll_cache[key]
    K = 2  # supersample for smooth edges
    PW, PH = 560, 560                       # paper size when open
    RH, RW = 44, PW + 70                    # roller size
    ph = int(PH * clamp(unroll))
    Wc, Hc = RW + 40, ph + 2 * RH + 40
    im = Image.new("RGBA", (Wc * K, Hc * K), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    S = lambda *v: [int(a * K) for a in v]
    cx = Wc / 2; top = 20 + RH / 2
    OUT = (92, 52, 32, 255)
    if ph > 2:
        x0, x1 = cx - PW / 2, cx + PW / 2; y0, y1 = top, top + RH / 2 + ph
        d.rectangle(S(x0, y0, x1, y1), fill=(246, 236, 212, 255), outline=OUT, width=5 * K)
        # 8x8 board, revealed from the top as the scroll opens
        m = 46; bs = (PW - 2 * m) / 8; by0 = y0 + RH / 2 + 18
        for r in range(8):
            for c in range(8):
                yy = by0 + r * bs
                if yy + bs > y1 - 6: continue
                col = (250, 243, 226, 255) if (r + c) % 2 == 0 else (198, 160, 116, 255)
                d.rectangle(S(x0 + m + c * bs, yy, x0 + m + (c + 1) * bs, yy + bs), fill=col)
        rows_shown = int(max(0, min(8, (y1 - 6 - by0) // bs)))
        if rows_shown:
            d.rectangle(S(x0 + m, by0, x0 + m + 8 * bs, by0 + rows_shown * bs), outline=OUT, width=4 * K)
    def roller(yc):
        d.rounded_rectangle(S(cx - RW / 2, yc - RH / 2, cx + RW / 2, yc + RH / 2), radius=RH * K / 2,
                            fill=(214, 168, 82, 255), outline=OUT, width=5 * K)
        d.rounded_rectangle(S(cx - RW / 2 + 14, yc - RH / 2 + 7, cx + RW / 2 - 14, yc - 4), radius=8 * K, fill=(238, 204, 128, 255))
        for ex in (cx - RW / 2 - 10, cx + RW / 2 + 10):
            d.ellipse(S(ex - 18, yc - 18, ex + 18, yc + 18), fill=(170, 120, 52, 255), outline=OUT, width=4 * K)
    roller(top)
    roller(top + RH / 2 + ph + (RH / 2 if ph > 2 else 0))
    if ph <= 2:   # rolled up: a soft ribbon around the middle
        d.rounded_rectangle(S(cx - 26, top - RH / 2 - 6, cx + 26, top + RH + 6), radius=10 * K, fill=(186, 72, 64, 255), outline=OUT, width=4 * K)
    im = im.resize((max(1, int(Wc * sc)), max(1, int(Hc * sc))), Image.LANCZOS)
    if len(_scroll_cache) > 300: _scroll_cache.clear()
    _scroll_cache[key] = im
    return im

# ------------------------------------------------------------------ small sprites
def _shadow():
    s = Image.new("RGBA", (400, 80), (0, 0, 0, 0))
    ImageDraw.Draw(s).ellipse([30, 18, 370, 62], fill=(30, 45, 25, 95))
    return s.filter(ImageFilter.GaussianBlur(10))
SHADOW = _shadow()

def _tile():
    s = Image.new("RGBA", (260, 110), (0, 0, 0, 0))
    ImageDraw.Draw(s).rounded_rectangle([35, 26, 225, 84], radius=16, fill=(255, 224, 135, 165))
    return s.filter(ImageFilter.GaussianBlur(8))
TILE = _tile()

def _spark():
    n = 120
    s = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    g = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([25, 25, 95, 95], fill=(255, 232, 160, 110))
    s.alpha_composite(g.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(s); c = n / 2; r = 40
    d.polygon([(c, c - r), (c + r * .2, c), (c, c + r), (c - r * .2, c)], fill=(255, 226, 140, 255))
    d.polygon([(c - r, c), (c, c + r * .2), (c + r, c), (c, c - r * .2)], fill=(255, 226, 140, 255))
    return s
SPARK = _spark()

def _glow(n=900):
    g = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([n * .2, n * .2, n * .8, n * .8], fill=(255, 236, 170, 150))
    return g.filter(ImageFilter.GaussianBlur(n * 0.09))
GLOW = _glow()

def _qmark():
    s = Image.new("RGBA", (130, 130), (0, 0, 0, 0)); d = ImageDraw.Draw(s)
    d.ellipse([8, 8, 122, 122], fill=(255, 250, 238, 235), outline=(200, 160, 80, 255), width=5)
    f = ImageFont.truetype(FONT_B, 76)
    d.text((65, 68), "?", font=f, fill=(95, 60, 35, 255), anchor="mm")
    return s
QMARK = _qmark()

_txt = {}
def caption_sprite(text):
    if text not in _txt:
        f = ImageFont.truetype(FONT_M, 42)
        words, lines, cur = text.split(), [], ""
        for w_ in words:
            t = (cur + " " + w_).strip()
            if f.getlength(t) > 1450 and cur: lines.append(cur); cur = w_
            else: cur = t
        lines.append(cur)
        lh = 58; tw = max(f.getlength(l) for l in lines)
        bw, bh = int(tw + 80), lh * len(lines) + 34
        s = Image.new("RGBA", (bw, bh), (0, 0, 0, 0)); d = ImageDraw.Draw(s)
        d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=28, fill=(28, 40, 30, 165))
        for i, l in enumerate(lines):
            d.text((bw / 2, 17 + lh * i + lh / 2), l, font=f, fill=(255, 251, 240, 255), anchor="mm")
        _txt[text] = s
    return _txt[text]

def name_sprite(text):
    return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
def _old_name_sprite(text):
    k = "name:" + text
    if k not in _txt:
        f = ImageFont.truetype(FONT_B, 58)
        tw = f.getlength(text); bw, bh = int(tw + 110), 104
        s = Image.new("RGBA", (bw + 20, bh + 20), (0, 0, 0, 0))
        sh = Image.new("RGBA", s.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([12, 14, bw + 8, bh + 10], radius=52, fill=(0, 0, 0, 60))
        s.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
        d = ImageDraw.Draw(s)
        d.rounded_rectangle([10, 8, bw + 10, bh + 8], radius=52, fill=(251, 244, 226, 255), outline=(206, 162, 72, 255), width=6)
        d.text((10 + bw / 2, 8 + bh / 2 + 3), text, font=f, fill=(92, 52, 32, 255), anchor="mm")
        _txt[k] = s
    return _txt[k]

def title_sprite(small, big):
    k = f"title:{small}|{big}"
    if k not in _txt:
        fb, fs = ImageFont.truetype(FONT_B, 92), ImageFont.truetype(FONT_M, 46)
        bw = int(max(fb.getlength(big), fs.getlength(small)) + 160); bh = 250 if small else 180
        s = Image.new("RGBA", (bw + 30, bh + 30), (0, 0, 0, 0))
        sh = Image.new("RGBA", s.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([15, 20, bw + 15, bh + 18], radius=60, fill=(0, 0, 0, 70))
        s.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)))
        d = ImageDraw.Draw(s)
        d.rounded_rectangle([15, 12, bw + 15, bh + 12], radius=60, fill=(251, 244, 226, 245), outline=(206, 162, 72, 255), width=7)
        if small:
            d.text((15 + bw / 2, 12 + 70), small, font=fs, fill=(150, 110, 60, 255), anchor="mm")
            d.text((15 + bw / 2, 12 + 160), big, font=fb, fill=(92, 52, 32, 255), anchor="mm")
        else:
            d.text((15 + bw / 2, 12 + bh / 2 + 4), big, font=fb, fill=(92, 52, 32, 255), anchor="mm")
        _txt[k] = s
    return _txt[k]

def paste_center(fr, spr, x, y, alpha=1.0, scale=1.0):
    if alpha <= 0.01: return
    if scale != 1.0:
        spr = spr.resize((max(1, int(spr.width * scale)), max(1, int(spr.height * scale))), Image.BILINEAR)
    if alpha < 0.999:
        spr = spr.copy(); a = spr.getchannel("A").point(lambda v: int(v * alpha)); spr.putalpha(a)
    fr.alpha_composite(spr, (int(x - spr.width / 2), int(y - spr.height / 2))) if _inside(fr, spr, x, y) else _safe_paste(fr, spr, int(x - spr.width / 2), int(y - spr.height / 2))

def _inside(fr, spr, x, y):
    x0, y0 = int(x - spr.width / 2), int(y - spr.height / 2)
    return x0 >= 0 and y0 >= 0 and x0 + spr.width <= fr.width and y0 + spr.height <= fr.height

def _safe_paste(fr, spr, x0, y0):
    cx0, cy0 = max(0, -x0), max(0, -y0)
    cx1, cy1 = min(spr.width, fr.width - x0), min(spr.height, fr.height - y0)
    if cx1 <= cx0 or cy1 <= cy0: return
    fr.alpha_composite(spr.crop((cx0, cy0, cx1, cy1)), (x0 + cx0, y0 + cy0))

# ------------------------------------------------------------------ drawing characters
CUR_SHOT = [0]; ACTORS = {}; SKINS = {}; PLAYERS = {}
def draw_char(fr, key, x, y, s, flip=False, bob=0.0, rot=0.0, sq=1.0, alpha=1.0, shadow=True, sil=0.0, rig=None,
              t=0.0, seed=0.0, head=0.0, tail_amp=5.0, wph=None, blink=True, lift=0.0, talk=0.0, sig=None, hop=None):
    ch = C[key]
    s = round(s * 250) / 250
    _bp = (t + seed * 1.37) % 4.1
    closed = blink and (_bp < 0.13 or (int((t + seed * 1.37) / 4.1) % 3 == 1 and 0.30 < _bp < 0.42))
    species = key.split("_")[0]
    # keyframed signature move (rokkorig.SIGNATURE) layered on top of everything else
    extra = {}
    # kangaroo hop: the big hind legs crouch, push and point the toes in the air
    if species == "roo" and hop is not None:
        ph, v = hop
        if ph == "crouch": extra["thigh"] = extra.get("thigh", 0) + 10 * v; extra["foot"] = extra.get("foot", 0) - 8 * v
        elif ph == "air":
            k_ = math.sin(v * math.pi); extra["thigh"] = extra.get("thigh", 0) - 10 * k_; extra["foot"] = extra.get("foot", 0) + 16 * k_
            extra["tail1"] = extra.get("tail1", 0) - 10 * k_
        elif ph == "land": extra["thigh"] = extra.get("thigh", 0) + 8 * math.sin(v * math.pi)
    aid = (CUR_SHOT[0], key, round(seed, 2))
    st = ACTORS.get(aid)
    if st is None: st = ACTORS[aid] = RR.ActorState()
    pose = RR.layered_pose(species, st, t, 1.0 / FPS, x, y, bob, flip, seed, head, tail_amp, wph, talk, extra)
    w0, h0s = max(1, round(ch.w * s)), max(1, round(ch.h * s))
    pad = int(0.16 * max(w0, h0s)) + 2                 # room for tails and ears to swing outside the box
    # RokkoPlayer: the keyframed timeline (same keys as in Figma), picked by what the animal is doing
    pl = PLAYERS.get(key)
    if pl is None: pl = PLAYERS[key] = RP.Character(key, tracks_key=key[:-2] + "_c")
    S = RP.SEG
    if hop is not None and species in ("roo", "horse"):
        ph, v = hop
        if ph == "crouch": u = math.asin(max(0.0, min(1.0, v))) * 2 / math.pi * 0.18
        elif ph == "air": u = 0.18 + v * 0.62
        else: u = 0.80 + v * 0.20
        tc = S["hop"][0] + u * (S["hop"][1] - S["hop"][0])
    elif sig is not None and 0 <= sig <= RR.SIGNATURE[species].d:
        tc = S["sig"][0] + sig
    elif wph is not None and species in ("lion", "queen", "ele", "horse"):
        tc = S["walk"][0] + 0.55 + ((wph / (2 * math.pi) + 0.5) % 1.0) * 1.1
    else:
        tc = (t + seed * 1.7) % (S["idle"][1] - S["idle"][0])
    ex = {"head": -head}
    if lift and species in ("ele", "horse", "lion", "queen"):
        ex["frontNearThigh"] = 18 * lift; ex["frontNearShin"] = -48 * lift
    spr = Image.fromarray(pl.render(tc, s, ch.bbox, pad, ex, blink=closed))
    if flip: spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
    if sq != 1.0:
        spr = spr.resize((max(1, int(spr.width * (1 + (1 - sq) * 0.6))), max(1, int(spr.height * sq))), Image.BILINEAR)
    if sil > 0:
        arr = np.array(spr).astype(np.float32)
        arr[..., :3] = arr[..., :3] * (1 - sil) + np.array([40, 52, 40]) * sil
        spr = Image.fromarray(arr.astype(np.uint8))
    if shadow:
        sw = w0 * 0.8
        sh = SHADOW.resize((max(1, int(sw)), max(1, int(sw * 0.2))), Image.BILINEAR)
        k = clamp(1 - bob / 260)
        paste_center(fr, sh, x, y - 2, alpha * (0.35 + 0.65 * k), 0.75 + 0.25 * k)
    yy = y - bob + pad
    if abs(rot) > 0.05:
        h0 = spr.height
        spr = spr.rotate(rot, resample=Image.BICUBIC, expand=True)
        paste_center(fr, spr, x, yy - h0 / 2, alpha)
    else:
        paste_center(fr, spr, x, yy - spr.height / 2, alpha)

def acc_point(key, x, y, s, flip=False):
    ch = C[key]; ax, ay = ch.acc
    if flip: ax = ch.w - ax
    return x - ch.w * s / 2 + ax * s, y - ch.h * s + ay * s

def tile(fr, x, y, s, a):
    if a > 0.01: paste_center(fr, TILE, x, y, a, s)

def sparkles(fr, x, y, t, s=1.0):
    for k, (dx, dy, st) in enumerate(((-45, -25, 0.0), (40, -60, 0.35), (10, 25, 0.7), (-30, 45, 1.05), (50, 20, 1.4))):
        u = (t - st) / 1.0
        if 0 <= u <= 1:
            paste_center(fr, SPARK, x + dx * s, y + dy * s, math.sin(u * math.pi) * 0.95, (0.45 + 0.2 * math.sin(u * math.pi)) * s)

def walk_motion(dist, stride=110, amp=8):
    ph = dist / stride * math.pi
    return abs(math.sin(ph)) * amp, math.sin(ph) * 1.6

def breathe(t, k=0.0): return 1 + 0.011 * math.sin((t + k) * 2 * math.pi / 3.2)

# ------------------------------------------------------------------ audio envelope (talk bob)
_env = {}
def env(clip, t):
    if clip not in _env:
        x = np.load(f"{HERE}/clips/{clip}.npy"); hop = SR // FPS
        e = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x), hop)])
        _env[clip] = e / (e.max() + 1e-6)
    e = _env[clip]; i = int(t * FPS)
    return float(e[i]) if 0 <= i < len(e) else 0.0

# ------------------------------------------------------------------ camera
def camera(fr, zoom, cx, cy):
    if zoom <= 1.001: return fr
    cw, chh = W / zoom, H / zoom
    x0 = clamp(cx - cw / 2, 0, W - cw); y0 = clamp(cy - chh / 2, 0, H - chh)
    return fr.resize((W, H), Image.BILINEAR, box=(x0, y0, x0 + cw, y0 + chh))

def dim(fr, a):
    if a > 0.01: fr.alpha_composite(Image.new("RGBA", (W, H), (20, 30, 22, int(255 * a))))

# ------------------------------------------------------------------ text for captions
TEXT = {
 "N1": "This is the Checkerwood Jungle.", "N2": "Two kingdoms live here.",
 "N3": "On this side is the Sunrise Kingdom. Its king is King Sunny.",
 "N4": "On this side is the Moonlight Kingdom. Its king is King Moony.",
 "N5": "Both kings want their kingdom to be the best in the jungle. But who is the wisest? Who is the best leader? The kings do not agree.",
 "N6": "One morning, a special message arrived for the whole jungle. All the animals came to the big clearing to see it.",
 "N7": "This is a very old story. It is about a game played on sixty-four squares. The kingdom that learns to play this game well will become the Guardian of the Jungle!",
 "N8": "There is one important rule. Being strong is not enough. To win, a kingdom must think carefully, keep its king safe, and work together.",
 "N9": "And so, the greatest game the jungle had ever seen was about to begin.",
 "N10": "Listen… who is coming?",
 "N11": "Every kingdom has a leader. Meet the lion kings! The king is the most important animal in the kingdom. If the king gets trapped, his kingdom loses the game. So keeping the king safe is always your most important job.",
 "N12": "Meet the queens! They are powerful and clever, and they can move in many directions.",
 "N13": "Meet the elephants! They are strong and steady, and they always protect their kingdom.",
 "N14": "Meet the kangaroos! They are quick and graceful.",
 "N15": "Meet the horses! They are adventurous, and they love to jump.",
 "N16": "Meet the squirrels! They are the smallest animals in the kingdom, but they are very brave. They always walk at the front.",
 "N17": "The squirrels have a big secret. We will find out what it is in a later lesson!",
 "N18": "The Moonlight Kingdom has one too!",
 "N19": "Look at the gold cross on the king's mane!", "N20": "Look at the queen's golden crown!",
 "N21": "Look at the tower on the elephant's back!", "N22": "Look at the kangaroo's tall pointed ears!",
 "N23": "Look at the horse's beautiful mane!", "N24": "Look at the little round ball on the squirrel's hat!",
 "N25": "Look! All our friends are standing on the sixty-four squares. Every animal has its own special way to move. Next time, we will learn how they play together!",
 "SUN1": "King Sunny: “My kingdom has a strong team!”", "SUN2": "King Sunny: “I am the king. I take one step at a time. Please keep me safe!”",
 "MOON": "King Moony: “My kingdom has a clever team!”",
 "QUEEN": "Queen: “I can go straight, and I can go on the slanty path. I can go very far!”",
 "ELE": "Elephant: “I walk in straight lines. Forward, backward, or to the side!”",
 "ROO": "Kangaroo: “I hop on the slanty path, from corner to corner!”",
 "HORSE": "Horse: “I jump in an L shape. I can even jump over other animals!”",
 "SQ": "Squirrels: “We are small. We step forward. Step, step, step!”",
}
def D_(c): return DURS[c]

# ------------------------------------------------------------------ shots
class Shot:
    def __init__(self, dur, draw, audio=(), bgname=None, fade=0.45, cap_top=False):
        self.dur, self.draw, self.audio, self.fade, self.cap_top = dur, draw, list(audio), fade, cap_top

def audio_active(audio, t):
    for clip, st in audio:
        if st <= t <= st + D_(clip): return clip, t - st
    return None, 0.0

def captions(fr, audio, t, top=False):
    for clip, st in audio:
        if st - 0.15 <= t <= st + D_(clip) + 0.35:
            a = clamp((t - st + 0.15) / 0.25) * clamp((st + D_(clip) + 0.35 - t) / 0.3)
            sp = caption_sprite(TEXT[clip]); paste_center(fr, sp, W / 2, (40 + sp.height / 2) if top else (H - 40 - sp.height / 2), a)

SHOTS = []

# ---- Title
def s_title(t, fr):
    fr.alpha_composite(bg_live("leafy2"))
    a = ease((t - 0.4) / 0.8)
    paste_center(fr, title_sprite("", "The Day the Jungle Changed"), W / 2, H / 2 - 30 + 12 * (1 - a), a)
    return camera(fr, 1.0 + 0.03 * t / 4, W / 2, H / 2)
# Title card removed from the opening clip (23 Nov 2026): the lesson starts straight in the jungle.
# L1_01_story.mp4 was cut 4.0 s at the start to match; subtitles and manifest moved back 4.0 s.
# SHOTS.append(Shot(4.0, s_title))

# ---- A: jungle push-in (N1)
def s_A(t, fr):
    fr.alpha_composite(bg_live("trees"))
    fr = camera(fr, 1.0 + 0.10 * ease(t / 5), W / 2, H * 0.55)
    if "fgW" not in _props: _props["fgW"] = prop("fg_leaves").resize((W, H), Image.BILINEAR)
    z = 1.04 + 0.22 * ease(t / 5)
    fr.alpha_composite(camera(_props["fgW"].copy(), z, W / 2 + 12 * math.sin(t * 0.8), H * 0.5))
    return fr
SHOTS.append(Shot(0.8 + D_("N1") + 1.6, s_A, [("N1", 0.8)]))

# ---- D: the two kings (N2..N5)
tD2 = 0.6; tD3 = tD2 + D_("N2") + 0.9; tD4 = tD3 + D_("N3") + 1.0; tD5 = tD4 + D_("N4") + 1.0
D_au = [("N2", tD2), ("N3", tD3), ("N4", tD4), ("N5", tD5)]
KS, KY = 0.5, 915
def walker(t, start, x0, x1, dur=3.0, stride=110):
    u = ease_out((t - start) / dur) if t >= start else 0.0
    x = lerp(x0, x1, u); dist = abs(x - x0)
    if start <= t <= start + dur:
        bob, rot = walk_motion(dist, stride); k = clamp(1.3 - u)
        return x, bob * k, rot * k, dist / stride * math.pi
    return x, 0.0, 0.0, None
def s_D(t, fr):
    fr.alpha_composite(bg_live("clearing"))
    for key, start, x0, x1, flip, sd in (("lion_c", tD3 + 0.2, -260, 620, False, 0.0), ("lion_d", tD4 + 0.2, 2180, 1300, True, 2.0)):
        if t < start: continue
        x, bob, rot, wph = walker(t, start, x0, x1)
        head = 0.0
        # waving hello = a happy little bounce + head tilt once they arrive
        hv = clamp((t - start - 3.1) / 1.2)
        bob += 22 * math.sin(hv * math.pi) if 0 < hv < 1 else 0
        head += 6 * math.sin(hv * math.pi) if 0 < hv < 1 else 0
        if t > tD5 + 3.6:   # puzzled head tilts while "who is the wisest?"
            head += 7 * math.sin((t - tD5 - 3.6) * 1.4 + sd)
        clip = "N3" if not flip else "N4"
        draw_char(fr, key, x, KY, KS * breathe(t, sd), flip, bob, rot, t=t, seed=sd, head=head, wph=wph)
    for nm, st, en in (("King Sunny", tD3 + 1.2, tD4 - 0.2), ("King Moony", tD4 + 1.2, tD5 - 0.2)):
        a = clamp((t - st) / 0.4) * clamp((en - t) / 0.4)
        paste_center(fr, name_sprite(nm), W / 2, 110, a)
    if t > tD5 + 3.0:
        a = clamp((t - tD5 - 3.0) / 0.6) * clamp((tD5 + D_("N5") + 0.8 - t) / 0.5)
        for x in (620, 1300):
            paste_center(fr, QMARK, x, KY - 470 + 8 * math.sin(t * 2.2 + x), a, 0.85)
    return fr
SHOTS.append(Shot(tD5 + D_("N5") + 1.0, s_D, D_au))

# ---- E: everyone gathers, the scroll, the kings speak, the rule
tE6 = 0.5; tE7 = tE6 + D_("N6") + 0.9; tS1 = tE7 + D_("N7") + 0.9; tM = tS1 + D_("SUN1") + 0.8
tE8 = tM + D_("MOON") + 1.0; tE9 = tE8 + D_("N8") + 1.0; E_end = tE9 + D_("N9") + 1.4
E_au = [("N6", tE6), ("N7", tE7), ("SUN1", tS1), ("MOON", tM), ("N8", tE8), ("N9", tE9)]
BACK = [("queen_c", 95, 745, 0.27), ("ele_c", 255, 752, 0.27), ("horse_c", 410, 748, 0.27), ("roo_c", 545, 742, 0.26),
        ("sq_c", 110, 862, 0.19), ("sq_c", 240, 870, 0.19)]
KX = (590, 1330)
def s_E(t, fr):
    fr.alpha_composite(bg_live("clearing"))
    grow = ease((t - tE7 - 0.3) / 1.4) * (1 - ease((t - tS1 + 1.4) / 1.2))
    for i, (key, x, y, s) in enumerate(BACK):
        for side in (0, 1):
            k2 = key if side == 0 else key.replace("_c", "_d")
            xf = x if side == 0 else W - x
            flip = side == 1; sd = i * 1.3 + side * 0.7
            st = tE6 + 0.3 + i * 0.35 + side * 0.15
            if t < st: continue
            x0 = -200 if side == 0 else W + 200
            xx, bob, rot, wph = walker(t, st, x0, xf, 2.6, 70)
            # everyone turns to look up at the scroll as it arrives and glows
            look = -5 * ease((t - tE6 - 4.0) / 1.0) * (1 - ease((t - tS1) / 1.0)) + 3 * grow
            # little excited hop when the scroll opens
            hv = clamp((t - tE7 - 1.2 - i * 0.12) / 0.5)
            hop = 18 * math.sin(hv * math.pi) if 0 < hv < 1 else 0
            draw_char(fr, k2, xx, y, s * breathe(t, sd), flip, bob + hop, rot, t=t, seed=sd, head=look, wph=wph)
    # kings
    for j, (key, x, flip, clip, cst) in enumerate((("lion_c", KX[0], False, "SUN1", tS1), ("lion_d", KX[1], True, "MOON", tM))):
        e = env(clip, t - cst)
        nod = 0
        if t > tE9 + 1.5:
            nod = 6 * math.sin(clamp((t - tE9 - 1.5) / 1.6) * math.pi * 2)
        talk = 6 * e
        draw_char(fr, key, x, KY, 0.42 * breathe(t, j), flip, 5 * e, 0, 1 - 0.02 * e, t=t, seed=j * 2.0,
                  head=nod + talk + 3 * grow)
    # scroll falls rolled up, lands, rises, opens to show the 64 squares, then rolls up again
    sst = tE6 + 3.4
    if t >= sst:
        u = ease((t - sst) / 3.0)
        y = lerp(-150, 900, u); x = W / 2 + 60 * math.sin((t - sst) * 2.4) * (1 - u)
        ang = 12 * math.sin((t - sst) * 2.4) * (1 - u)
        sc = 0.42; unroll = 0.0
        if grow > 0.001:
            y = lerp(900, 400, grow); sc = lerp(0.42, 0.62, grow)
            unroll = ease((t - tE7 - 1.2) / 1.6) * (1 - ease((t - tS1 + 1.9) / 1.0))
        if t >= sst + 3.0 and grow < 0.5:
            paste_center(fr, SHADOW, x, 905, 0.6, 0.55)
        if grow > 0.01:
            dim(fr, 0.30 * grow)
            paste_center(fr, GLOW, x, y, 0.85 * grow, 0.8 + 0.04 * math.sin(t * 2))
            if unroll > 0.95:
                sparkles(fr, x - 230, y - 160, (t - tE7) % 1.9, 0.9)
                sparkles(fr, x + 220, y + 120, (t - tE7 + 0.9) % 1.9, 0.9)
        sp = scroll_sprite(unroll, sc)
        bobs = 6 * math.sin(t * 1.6) * grow
        if abs(ang) > 0.1: sp = sp.rotate(ang, resample=Image.BICUBIC, expand=True)
        land = (t >= sst + 3.0) and grow < 0.01
        squash = 1.0
        if sst + 3.0 <= t < sst + 3.35: squash = 1 - 0.12 * math.sin((t - sst - 3.0) / 0.35 * math.pi)
        if squash != 1.0: sp = sp.resize((int(sp.width * (2 - squash)), int(sp.height * squash)), Image.BILINEAR)
        paste_center(fr, sp, x, (y - sp.height / 2) if grow < 0.01 else y + bobs)
    z, cx, cy = 1.0, W / 2, H / 2
    for x, st, d in ((KX[0], tS1, D_("SUN1")), (KX[1], tM, D_("MOON"))):
        k = ease((t - st + 0.9) / 0.8) * (1 - ease((t - st - d - 0.1) / 0.8))
        if k > 0: z, cx, cy = lerp(1.0, 1.55, k), lerp(W / 2, x, k), lerp(H / 2, 640, k)
    fr = camera(fr, z, cx, cy)
    if tE8 - 0.5 < t < tE9 + 1.2:
        a_dim = clamp((t - tE8 + 0.5) / 0.6) * clamp((tE9 + 1.2 - t) / 0.8)
        dim(fr, 0.42 * a_dim)
        for k, rel in enumerate((5.6, 7.0, 8.4)):
            st = tE8 + rel
            a = clamp((t - st) / 0.5) * clamp((tE9 + 1.2 - t) / 0.8)
            pop = 1 + 0.12 * math.sin(clamp((t - st) / 0.5) * math.pi)
            paste_center(fr, prop(f"icon{k}"), W / 2 + (k - 1) * 380, 470 + 6 * math.sin(t * 1.5 + k), a, 0.40 * pop)
    return fr
SHOTS.append(Shot(E_end, s_E, E_au))

# ---- Scene 2 title
def s_title2(t, fr):
    fr.alpha_composite(bg_live("meadow"))
    a = ease((t - 0.3) / 0.7)
    return camera(fr, 1.0 + 0.03 * t / 3.5, W / 2, H / 2)
SHOTS.append(Shot(3.6, s_title2))

# ---- Scene 2 segments
FOOT = 880
def path_eval(moves, t, x0, y0, sgn):
    x, y = x0, y0; tt = t; lit = []; bob = rot = 0.0; sq = 1.0; swing = 0.0; stomp = 0.0; wph = None; air = False; hop = None
    for kind, dx, dy, dur, ex in moves:
        dx *= sgn
        if tt <= 0: break
        u = clamp(tt / dur)
        if kind == "walk":
            e = ease(u); cx, cy = x + dx * e, y + dy * e
            dist = math.hypot(dx * e, dy * e)
            if u < 1:
                b, r = walk_motion(dist, 95, 7); bob, rot = b, r; wph = dist / 95 * math.pi
                swing = 10 * math.sin(wph)
            steps = max(1, round(math.hypot(dx, dy) / 170))
            for k in range(1, steps + 1):
                if e >= k / steps - 0.02: lit.append((x + dx * k / steps, y + dy * k / steps))
            x, y = cx, cy
        elif kind == "hop":
            h = ex or 120; crouch, airt = 0.18, 0.62
            if u < crouch:
                sq = 1 - 0.08 * math.sin(u / crouch * math.pi / 2); cx, cy = x, y
                if u < 1: hop = ("crouch", math.sin(u / crouch * math.pi / 2))
            elif u < crouch + airt:
                v = (u - crouch) / airt; e = ease(v)
                cx, cy = x + dx * e, y + dy * e; bob = h * 4 * v * (1 - v); sq = 1.04; air = True
                rot = -6 * math.sin(v * math.pi) * sgn; hop = ("air", v)
            else:
                v = (u - crouch - airt) / (1 - crouch - airt)
                cx, cy = x + dx, y + dy; sq = 1 - 0.07 * math.sin(v * math.pi)
                if u < 1: hop = ("land", v)
            if u >= crouch + airt - 0.02: lit.append((x + dx, y + dy))
            x, y = cx, cy
        elif kind == "stomp":
            stomp = u
            if u > 0.62: lit.append((x, y))
        tt -= dur
    return x, y, bob, rot, sq, lit, swing, stomp, wph, air, hop

def dscale(y): return 1 + (y - FOOT) / 700.0

def seg(cream, dark, base_s, moves, intro, voice, look, name, with_listen=False):
    """with_listen=True (first animal only): 'Listen… who is coming?' + the twin arrives later with 'The Moonlight
    Kingdom has one too!'. Otherwise both kingdoms arrive together, mirrored, while the narrator introduces them."""
    walkin = 2.0; pat = sum(m[3] for m in moves)
    if with_listen:
        t0 = 0.5; t1 = t0 + D_("N10") + 0.8
    else:
        t0 = None; t1 = 0.6
    t_pat_end = t1 + walkin + pat
    t2 = max(t1 + D_(intro), t_pat_end) + 0.5
    t3 = t2 + D_(voice) + 0.7
    au = [(intro, t1), (voice, t2), (look, t3)]
    if with_listen:
        au.insert(0, ("N10", t0))
        t4 = t3 + D_(look) + 1.3; au.append(("N18", t4))
        end = max(t4 + D_("N18"), t4 + walkin + pat) + 1.4
    else:
        t4 = t1 + 0.25
        end = t3 + D_(look) + 1.6
    SX, DXs = 380, 1600
    def final_xy(sgn, x0):
        x, y = x0, FOOT
        for kind, dx, dy, dur, ex in moves:
            if kind in ("walk", "hop"): x += dx * sgn; y += dy
        return x, y
    fxc, fyc = final_xy(1, SX)
    def draw(t, fr):
        fr.alpha_composite(bg_live("stage"))
        if with_listen and t0 - 0.2 < t < t1 + 0.4:
            a = clamp((t - t0 + 0.2) / 0.5) * clamp((t1 + 0.4 - t) / 0.4)
            draw_char(fr, cream, 40 + 25 * math.sin(t * 1.8), FOOT - 20, base_s, False, 0, 0, 1, a, False, sil=0.82, t=t, blink=False)
        tiles = []; actors = []
        for who, key, st, sgn, x0 in (("c", cream, t1, 1, SX), ("d", dark, t4, -1, DXs)):
            if t < st: continue
            off = -320 if sgn == 1 else W + 320
            stomp = 0; air = False; swing = 0.0; hop = None
            if t < st + walkin:
                u = ease_out((t - st) / walkin); x = lerp(off, x0, u); y = FOOT
                bob, rot = walk_motion(abs(x - off), 100, 7); sq = 1; lit = []; wph = abs(x - off) / 100 * math.pi
                swing = 10 * math.sin(wph)
            else:
                x, y, bob, rot, sq, lit, swing, stomp, wph, air, hop = path_eval(moves, t - st - walkin, x0, FOOT, sgn)
            tiles.extend(lit)
            actors.append((who, key, x, y, bob, rot, sq, swing, stomp, sgn, wph, air, hop))
        for px, py in tiles:
            a = 0.85 * (1 - 0.55 * ease((t - end + 2.5) / 2))
            tile(fr, px, py + 4, dscale(py), a)
        for who, key, x, y, bob, rot, sq, swing, stomp, sgn, wph, air, hop in sorted(actors, key=lambda a: a[3]):
            s = base_s * dscale(y)
            e = env(voice, t - t2) if who == "c" else 0
            sd = 0.0 if who == "c" else 2.3
            lift = 0.0
            if stomp > 0:
                lift = ease(stomp / 0.35) if stomp < 0.5 else (1 - ((stomp - 0.5) / 0.12) ** 2 if stomp < 0.62 else 0)
                lift = clamp(lift)
            if 0.62 < stomp < 0.8: sq = 1 - 0.04 * math.sin((stomp - 0.62) / 0.18 * math.pi)
            # after arriving: the twin turns its head toward the speaker; everyone reacts to "look closer"
            head = 7 * e + (8 if air else 0)
            if who == "d" and t > t2: head += 3 * math.sin((t - t2) * 0.9)
            proud = 10 * math.sin(clamp((t - t3) / 1.2) * math.pi) if t3 < t < t3 + 1.2 else 0
            draw_char(fr, key, x, y, s * breathe(t, sd) * (1 + 0.015 * e), sgn == -1, bob + 5 * e + proud, rot, sq,
                      t=t, seed=sd, head=head, wph=wph, tail_amp=9 if t > t2 else 5, lift=lift,
                      sig=(t - t2 - 0.2 - (0.5 if who == "d" else 0)) if t > t2 else None, hop=hop)
            if stomp > 0.62:
                v = (stomp - 0.62) / 0.38
                for dxx in (-1, 1):
                    paste_center(fr, prop("dust"), x + dxx * (60 + 90 * ease_out(v)) * s / 0.5, y - 25, 0.75 * (1 - v), 0.09 + 0.05 * ease_out(v))
        a = clamp((t - t_pat_end - 0.2) / 0.4) * clamp((t3 + D_(look) + 0.5 - t) / 0.4)
        paste_center(fr, name_sprite(name), W / 2, 110, a)
        ax, ay = acc_point(cream, fxc, fyc, base_s * dscale(fyc))
        k = ease((t - t3 + 0.6) / 1.0) * (1 - ease((t - t3 - D_(look) - 0.2) / 1.0))
        if t3 - 0.2 < t < t3 + D_(look) + 0.6:
            sparkles(fr, ax, ay + 10, (t - t3 - 0.2) % 1.9, 1.0)
        return camera(fr, lerp(1.0, 1.5, k), lerp(W / 2, ax, k), lerp(H / 2, ay + 160, k))
    return Shot(end, draw, au)

S2 = [
    ("lion_c", "lion_d", 0.5, [("walk", 170, 0, 1.0, None), ("pause", 0, 0, 0.7, None), ("walk", 170, 0, 1.0, None), ("pause", 0, 0, 0.6, None)], "N11", "SUN2", "N19", "The Lion Kings", True),
    ("queen_c", "queen_d", 0.5, [("walk", 170, 0, 1.1, None), ("pause", 0, 0, 0.3, None), ("walk", 170, -70, 1.2, None), ("pause", 0, 0, 0.4, None)], "N12", "QUEEN", "N20", "The Lioness Queens"),
    ("ele_c", "ele_d", 0.48, [("walk", 340, 0, 2.2, None), ("pause", 0, 0, 0.3, None), ("stomp", 0, 0, 1.6, None)], "N13", "ELE", "N21", "The Elephants"),
    ("roo_c", "roo_d", 0.45, [("hop", 170, -70, 1.0, 120), ("pause", 0, 0, 0.25, None), ("hop", 170, -70, 1.0, 120), ("pause", 0, 0, 0.4, None)], "N14", "ROO", "N22", "The Kangaroos"),
    ("horse_c", "horse_d", 0.46, [("pause", 0, 0, 0.3, None), ("hop", 340, -70, 1.5, 210), ("pause", 0, 0, 0.5, None)], "N15", "HORSE", "N23", "The Horses"),
]
for args in S2:
    SHOTS.append(seg(*args))

# ---- squirrels (both rows arrive together)
def squirrels():
    t1 = 0.6; walkin = 3.0
    hop_st = t1 + walkin + 0.3; t_pat_end = hop_st + 8 * 0.3 + 0.9
    t2 = max(t1 + D_("N16"), t_pat_end) + 0.5; t3 = t2 + D_("SQ") + 0.7
    t5 = t3 + D_("N24") + 1.2
    end = t5 + D_("N17") + 1.6
    au = [("N16", t1), ("SQ", t2), ("N24", t3), ("N17", t5)]
    XS = [270 + i * 197 for i in range(8)]
    sC, sD = 0.215, 0.17
    yC, yD = FOOT + 10, FOOT - 235
    def draw(t, fr):
        fr.alpha_composite(bg_live("stage"))
        rows = []
        for side, key, st, hst, y0, s, sgn, dy in (("d", "sq_d", t1 + 0.3, hop_st + 0.15, yD, sD, -1, 45), ("c", "sq_c", t1, hop_st, yC, sC, 1, -45)):
            if t < st: continue
            for i in range(8):
                xf = XS[i] if sgn == 1 else XS[7 - i]
                u = ease_out((t - st - i * 0.08) / walkin)
                xs0 = xf - 1700 * sgn
                x = lerp(xs0, xf, u)
                wph = abs(x - xs0) / 60 * math.pi if u < 1 else None
                bob, rot = walk_motion(abs(x - xs0), 60, 5) if u < 1 else (0, 0)
                y = y0; sq = 1.0; head = 0
                hs = hst + i * 0.3
                if t > hs:
                    v = clamp((t - hs) / 0.6)
                    y = y0 + dy * ease(v); bob = 45 * 4 * v * (1 - v); head = 8 * math.sin(v * math.pi)
                    if v >= 1: tile(fr, x, y + 4, dscale(y), 0.8)
                e = env("SQ", t - t2) if side == "c" else 0
                # the big secret: everyone leans and looks around curiously
                if t > t5: head += 6 * math.sin((t - t5) * 1.3 + i)
                rows.append((y, key, x, s * dscale(y) * breathe(t, i), sgn == -1, bob + 4 * e, rot, i + (0 if side == "c" else 10), head + 7 * e, wph))
        for y, key, x, s, flip, bob, rot, sd, head, wph in sorted(rows, key=lambda r: r[0]):
            draw_char(fr, key, x, y, s, flip, bob, rot, t=t, seed=sd, head=head, wph=wph, tail_amp=8)
        a = clamp((t - t_pat_end) / 0.4) * clamp((t3 + D_("N24") + 0.5 - t) / 0.4)
        paste_center(fr, name_sprite("The Squirrels"), W / 2, 110, a)
        ax, ay = acc_point("sq_c", XS[3], yC - 45, sC * dscale(yC - 45))
        k = ease((t - t3 + 0.6) / 1.0) * (1 - ease((t - t3 - D_("N24") - 0.2) / 1.0))
        if t3 - 0.2 < t < t3 + D_("N24") + 0.6:
            sparkles(fr, ax, ay + 5, (t - t3 - 0.2) % 1.9, 0.7)
        if t > t5 + 0.6:
            a = clamp((t - t5 - 0.6) / 0.6) * clamp((end - 0.3 - t) / 0.5)
            paste_center(fr, QMARK, W / 2, 330 + 10 * math.sin(t * 2), a, 1.0)
        return camera(fr, lerp(1.0, 1.9, k), lerp(W / 2, ax, k), lerp(H / 2, ay + 120, k))
    return Shot(end, draw, au)
SHOTS.append(squirrels())

# ---- Ending: everyone on the 64 squares
BACKROW = ["ele", "horse", "roo", "queen", "lion", "roo", "horse", "ele"]
def board_geom():
    s = max(W / 1376, H / 768); ox = (1376 * s - W) / 2; oy = (768 * s - H) / 2
    T = lambda x, y: (x * s - ox, y * s - oy)
    (tlx, ty), (trx, _) = T(488, 355), T(962, 355)
    (blx, by), (brx, _) = T(330, 652), T(1112, 652)
    return tlx, trx, ty, blx, brx, by
GL = board_geom()
def sq_center(r, c):
    tlx, trx, ty, blx, brx, by = GL
    fy = (r + 0.5) / 8
    y = lerp(ty, by, fy); xl = lerp(tlx, blx, fy); xr = lerp(trx, brx, fy)
    return lerp(xl, xr, (c + 0.5) / 8), y + (by - ty) / 8 * 0.28, (xr - xl) / 8
def s_end(t, fr):
    fr.alpha_composite(bg_live("board"))
    pieces = []
    for r, side in ((0, "d"), (1, "d"), (6, "c"), (7, "c")):
        for c in range(8):
            kind = "sq" if r in (1, 6) else BACKROW[c]
            key = f"{kind}_{side}"
            x, y, sqw = sq_center(r, c)
            fac = 0.85 if kind == "sq" else (1.18 if kind in ("ele", "horse", "lion") else 1.05)
            s = fac * sqw / C[key].w
            # a happy wave of little hops runs along each row
            st = 2.2 + c * 0.18 + (0 if r in (6, 7) else 0.9) + (0.45 if r in (1, 6) else 0)
            v = clamp((t - st) / 0.6); bob = 4 * v * (1 - v) * sqw * 0.35
            pieces.append((y, key, x, s, side == "d", bob, r * 8 + c))
    for y, key, x, s, flip, bob, sd in sorted(pieces, key=lambda p: p[0]):
        draw_char(fr, key, x, y, s * breathe(t, sd), flip, bob, 0, t=t, seed=sd, tail_amp=7)
    z = lerp(1.6, 1.22, ease((t - 0.5) / 7.0))
    return camera(fr, z, W / 2, lerp(760, 690, ease((t - 0.5) / 7.0)))
SHOTS.append(Shot(1.0 + D_("N25") + 2.0, s_end, [("N25", 1.0)], cap_top=True))

def s_bye(t, fr):
    fr.alpha_composite(bg_live("leafy2"))
    a = ease((t - 0.3) / 0.7)
    paste_center(fr, title_sprite("", "See you next time!"), W / 2, H / 2 - 30 + 12 * (1 - a), a)
    return fr
SHOTS.append(Shot(4.0, s_bye))


# ------------------------------------------------------------------ timeline
STARTS = []; acc = 0.0
for sh in SHOTS: STARTS.append(acc); acc += sh.dur
TOTAL = acc
NFRAMES = int(math.ceil(TOTAL * FPS))

def render_frame(i):
    T = i / FPS
    k = max(j for j in range(len(SHOTS)) if STARTS[j] <= T + 1e-9)
    sh = SHOTS[k]; t = T - STARTS[k]
    CUR_SHOT[0] = k
    fr = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    T_NOW[0] = T
    fr = sh.draw(t, fr)
    # living scenery on top of the shot (life.py)
    title = sh.draw in (s_title, s_bye, s_title2)
    LIFE.pollen(fr, T)
    if not title and sh.draw is not s_E:      # the scroll + rule scene stays calm: light and pollen only
        for kb in range(1 if sh.draw is s_end else 2): LIFE.butterfly(fr, T, kb + 3 * k)
        LIFE.falling_leaves(fr, T, 1 if sh.draw is s_end else 2)
    fr = LIFE.light(fr, T, 0.7 if sh.draw is s_end else 1.0)
    f = min(clamp(t / sh.fade), clamp((sh.dur - t) / sh.fade))
    if f < 1:
        fr.alpha_composite(Image.new("RGBA", (W, H), (18, 26, 20, int(255 * (1 - ease(f))))))
    return fr.convert("RGB")

def build_audio(path):
    out = np.zeros(int((TOTAL + 1) * SR), np.float32)
    for k, sh in enumerate(SHOTS):
        for clip, st in sh.audio:
            x = np.load(f"{HERE}/clips/{clip}.npy")
            a = int((STARTS[k] + st) * SR); out[a:a + len(x)] += x
    out = np.clip(out / max(1e-6, np.abs(out).max()) * 0.89, -1, 1)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "aac", "-b:a", "192k", path],
                   input=out.tobytes(), check=True)

if __name__ == "__main__":
    if sys.argv[1] == "audio":
        build_audio(f"{HERE}/parts/audio.m4a"); print("audio", TOTAL)
    elif sys.argv[1] == "still":
        render_frame(int(float(sys.argv[2]) * FPS)).save(f"{HERE}/still.png")
    elif sys.argv[1] == "info":
        for k, sh in enumerate(SHOTS): print(k, round(STARTS[k], 2), round(sh.dur, 2))
        print("TOTAL", TOTAL, NFRAMES)
    else:
        part, n = int(sys.argv[1]), int(sys.argv[2])
        a, b = NFRAMES * part // n, NFRAMES * (part + 1) // n
        os.makedirs(f"{HERE}/parts6", exist_ok=True)
        p = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                              "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p", f"{HERE}/parts6/part_{part}.mp4"],
                             stdin=subprocess.PIPE)
        for i in range(max(0, a - 36), a): render_frame(i)   # warm up the springs
        for i in range(a, b):
            p.stdin.write(render_frame(i).tobytes())
            if (i - a) % 120 == 0: print(part, i, "/", b, flush=True)
        p.stdin.close(); p.wait()
        print("done part", part)
