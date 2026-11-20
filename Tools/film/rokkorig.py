"""RokkoRig: a small bones + skin + springs engine for the cut-out characters (written from scratch).

Ideas (same family as Rive / Spine / DragonBones, none of their code):
  * Skeleton: bones with a parent, a pivot and an end point, in the sprite's rest space (fractions of the cropped image).
  * Skin: every pixel gets smooth weights per bone (distance to the bone segment, painted masks), normalised.
  * Pose: local rotation / scale per bone -> forward kinematics -> world affine per bone.
  * Deform: linear blend skinning, inverted per pixel (fixed-point iteration) and resampled with cv2.remap.
  * Layers: idle, walk, talk and look are separate layers summed into one pose (like a state-machine blend).
  * Springs: tails, ears and trunks follow the body with lag and overshoot (damped springs, stepped at film fps).
"""
import math
import numpy as np
import cv2

# name: (parent, pivot, end, sigma (fraction of sprite diagonal), include box or None, exclude boxes)
# Coordinates are fractions (x, y) of the cropped character sprite.
B = lambda parent, p, e, sg=0.06, inc=None, exc=(): (parent, p, e, sg, inc, list(exc))
SKELETONS = {
 "lion": {
   "chest": B("root", (.58, .62), (.62, .45), .10, (.40, 0, 1, .72)),
   "head":  B("chest", (.56, .62), (.60, .30), .17, (.31, 0, 1, .66)),
   "earL":  B("head", (.47, .34), (.44, .27), .035, (.38, .2, .52, .38)),
   "earR":  B("head", (.73, .32), (.76, .26), .035, (.68, .2, .82, .37)),
   "tail1": B("root", (.29, .62), (.22, .72), .035, (0, .45, .31, 1), [(.235, .64, .40, 1)]),
   "tail2": B("tail1", (.22, .72), (.15, .68), .04, (0, .40, .26, 1), [(.235, .64, .40, 1)]),
   "tail3": B("tail2", (.15, .68), (.13, .52), .07, (0, .28, .24, .76)),
 },
 "queen": {
   "chest": B("root", (.62, .58), (.68, .45), .08, (.45, 0, 1, .66)),
   "neck":  B("chest", (.66, .55), (.73, .36), .07, (.55, 0, 1, .6)),
   "head":  B("neck", (.72, .40), (.80, .26), .10, (.58, 0, 1, .47)),
   "ear":   B("head", (.67, .28), (.63, .21), .035, (.58, .1, .72, .33)),
   "tail1": B("root", (.40, .52), (.33, .58), .03, (.25, .42, .44, .66), [(.36, .58, .6, 1)]),
   "tail2": B("tail1", (.33, .58), (.25, .73), .035, (.15, .50, .36, .82), [(.31, .62, .6, 1), (.30, .76, .6, 1)]),
   "tail3": B("tail2", (.25, .73), (.13, .66), .06, (0, .50, .28, .85), [(.30, .76, .6, 1)]),
 },
 "ele": {
   "chest":  B("root", (.50, .60), (.66, .45), .12, (.35, 0, 1, .74), [(.40, 0, .68, .30)]),
   "head":   B("chest", (.62, .55), (.76, .40), .15, (.55, .1, 1, .76), [(.40, 0, .68, .30)]),
   "ear":    B("head", (.62, .32), (.58, .56), .09, (.48, .26, .74, .62), [(.40, 0, .68, .30)]),
   "trunk1": B("head", (.82, .58), (.87, .66), .05, (.78, .45, 1, .8)),
   "trunk2": B("trunk1", (.87, .66), (.94, .72), .05, (.82, .55, 1, .8)),
   "tail1":  B("root", (.13, .42), (.09, .55), .035, (0, .3, .17, .8)),
   "tail2":  B("tail1", (.09, .55), (.06, .70), .04, (0, .45, .14, .8)),
 },
 "roo": {
   "chest": B("root", (.68, .62), (.70, .45), .09, (.50, .3, 1, .8)),
   "neck":  B("chest", (.67, .46), (.68, .36), .06, (.58, .25, 1, .5)),
   "head":  B("neck", (.68, .38), (.82, .31), .08, (.55, .2, 1, .44)),
   "earL":  B("head", (.52, .30), (.42, .15), .04, (.34, .06, .56, .33), [(.56, 0, 1, .27)]),
   "earR":  B("head", (.60, .28), (.565, .12), .035, (.52, .03, .69, .31)),
   "thigh": B("root", (.53, .60), (.50, .79), .06, (.40, .50, .64, .86), [(.62, .45, 1, .72)]),
   "foot":  B("thigh", (.49, .82), (.72, .845), .035, (.40, .74, .82, .97)),
   "tail1": B("root", (.40, .72), (.29, .81), .04, (.18, .62, .44, .92), [(.42, .74, 1, 1)]),
   "tail2": B("tail1", (.30, .83), (.17, .82), .045, (.06, .62, .36, .92)),
   "tail3": B("tail2", (.17, .82), (.08, .71), .05, (0, .55, .22, .88)),
 },
 "horse": {
   "chest": B("root", (.62, .60), (.66, .45), .09, (.45, 0, 1, .70)),
   "neck":  B("chest", (.64, .55), (.68, .35), .10, (.48, .1, 1, .6)),
   "head":  B("neck", (.68, .38), (.82, .33), .09, (.62, .08, 1, .46)),
   "ear":   B("head", (.69, .20), (.68, .14), .03, (.63, .1, .75, .24)),
   "tail1": B("root", (.38, .46), (.32, .52), .035, (.22, .38, .42, .62)),
   "tail2": B("tail1", (.32, .52), (.27, .62), .05, (.12, .45, .36, .8), [(.24, .66, .5, 1)]),
   "tail3": B("tail2", (.27, .62), (.15, .70), .06, (0, .5, .33, .82), [(.24, .66, .5, 1)]),
 },
 "sq": {
   "chest": B("root", (.70, .72), (.72, .55), .09, (.6, .3, 1, .82)),
   "head":  B("chest", (.70, .56), (.80, .40), .11, (.6, 0, 1, .62)),
   "tail1": B("root", (.47, .76), (.38, .62), .07, (.25, .45, .62, .9)),
   "tail2": B("tail1", (.38, .62), (.27, .45), .09, (0, .25, .5, .8), [(.47, 0, 1, .52)]),
   "tail3": B("tail2", (.27, .45), (.18, .33), .09, (0, .1, .42, .62), [(.45, 0, 1, .52)]),
 },
}

ORDER = {sp: sorted(sk, key=lambda n: _depth(sk, n)) for sp, sk in SKELETONS.items()} if False else None
def _depth(sk, n):
    d = 0
    while sk[n][0] != "root": n = sk[n][0]; d += 1
    return d
ORDER = {sp: sorted(sk, key=lambda n: _depth(sk, n)) for sp, sk in SKELETONS.items()}


def _seg_dist(X, Y, p, e):
    vx, vy = e[0] - p[0], e[1] - p[1]
    L2 = vx * vx + vy * vy + 1e-9
    u = np.clip(((X - p[0]) * vx + (Y - p[1]) * vy) / L2, 0, 1)
    return np.hypot(X - (p[0] + u * vx), Y - (p[1] + u * vy))


def _box(X, Y, b, soft):
    x0, y0, x1, y1 = b
    return (np.clip((X - x0) / soft + 0.5, 0, 1) * np.clip((x1 - X) / soft + 0.5, 0, 1) *
            np.clip((Y - y0) / soft + 0.5, 0, 1) * np.clip((y1 - Y) / soft + 0.5, 0, 1))


ROOT = {   # the body bone (hips -> shoulders) and its radius; every species has one
 "lion": ((.30, .60), (.58, .62), .10), "queen": ((.40, .55), (.62, .58), .07), "ele": ((.18, .50), (.60, .58), .17),
 "roo": ((.55, .72), (.70, .60), .12), "horse": ((.38, .52), (.62, .58), .09), "sq": ((.60, .78), (.70, .70), .08),
}
SOFT = 0.022
FALLBACK = 9.0   # width of the blend between neighbouring bones (fraction of the diagonal)


class Skin:
    """Envelope weights for one species at one sprite size (w, h): each pixel follows its nearest bones,
    blended softly; boxes paint where a bone may act. Cached by the caller."""
    def __init__(self, species, w, h, bbox=None, full=1024, legs_separate=False):
        """w, h: sprite size in pixels. bbox: where the sprite sits in the full source frame (bone fractions are of
        that frame); None = the sprite is the full frame."""
        sk = SKELETONS[species]; self.names = ORDER[species]; self.sk = sk; self.w, self.h = w, h
        bx0, by0, bx1, by1 = bbox or (0, 0, full, full)
        # pixel grid of the sprite, expressed in full-frame fractions
        X, Y = np.meshgrid((bx0 + (np.arange(w, dtype=np.float32) + .5) / w * (bx1 - bx0)) / full,
                           (by0 + (np.arange(h, dtype=np.float32) + .5) / h * (by1 - by0)) / full)
        self.to_px = lambda f: ((f[0] * full - bx0) / (bx1 - bx0) * w, (f[1] * full - by0) / (by1 - by0) * h)
        asp = 1.0; Xa = X; diag = math.sqrt(2.0); s = SOFT * diag   # tuned on the full frame
        rp, re, rr = ROOT[species]
        d0 = np.maximum(0, _seg_dist(Xa, Y, (rp[0] * asp, rp[1]), (re[0] * asp, re[1])) - rr * diag)
        logits = [np.maximum(-(d0 / s) ** 2, -FALLBACK)]   # the body owns anything far from every bone
        for n in self.names:
            par, p, e, rad, inc, exc = sk[n]
            d = np.maximum(0, _seg_dist(Xa, Y, (p[0] * asp, p[1]), (e[0] * asp, e[1])) - rad * diag)
            m = np.ones_like(X)
            if inc: m *= _box(X, Y, inc, 0.06)
            for b in exc:
                if legs_separate and b[1] >= 0.55: continue   # leg guards are not needed when legs are their own layers
                m *= 1 - _box(X, Y, b, 0.05)
            logits.append(-(d / s) ** 2 - 60.0 * (1 - m))
        L = np.stack(logits); L -= L.max(0, keepdims=True)
        E = np.exp(L); E /= E.sum(0, keepdims=True)
        self.Wr = E[0].astype(np.float32); self.W = E[1:].astype(np.float32)
        self.px = {n: self.to_px(sk[n][1]) for n in self.names}


def _aff(rot_deg, sx, sy, piv, tx=0.0, ty=0.0):
    """3x3: translate(piv) * R * S * translate(-piv), plus a translation."""
    c, s = math.cos(math.radians(rot_deg)), math.sin(math.radians(rot_deg))
    px, py = piv
    A = np.array([[c * sx, -s * sy], [s * sx, c * sy]])
    t = np.array([px, py]) - A @ np.array([px, py]) + np.array([tx, ty])
    M = np.eye(3); M[:2, :2] = A; M[:2, 2] = t
    return M


def world(skin, pose):
    """pose: {bone: (rot_deg, sx, sy)} -> {bone: 3x3 world matrix}. Positive rot = clockwise on screen (image y down)."""
    Mw = {}
    for n in skin.names:
        par = skin.sk[n][0]
        r, sx, sy = pose.get(n, (0.0, 1.0, 1.0))
        L = _aff(r, sx, sy, skin.px[n])
        Mw[n] = (Mw[par] @ L) if par != "root" else L
    return Mw


def deform(img, skin, pose, iters=2):
    """Linear blend skinning of an RGBA image (numpy uint8 [h, w, 4]) with the pose; returns uint8 array."""
    h, w = img.shape[:2]
    if not pose or all(abs(v[0]) < 0.03 and abs(v[1] - 1) < 1e-4 and abs(v[2] - 1) < 1e-4 for v in pose.values()):
        return img
    Mw = world(skin, pose)
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    # first guess: weights at the destination, inverse matrices
    inv = [np.linalg.inv(Mw[n]) for n in skin.names]
    sx = skin.Wr * X; sy = skin.Wr * Y
    for k, Mi in enumerate(inv):
        wk = skin.W[k]
        sx += wk * (Mi[0, 0] * X + Mi[0, 1] * Y + Mi[0, 2])
        sy += wk * (Mi[1, 0] * X + Mi[1, 1] * Y + Mi[1, 2])
    # refine: src += dst - F(src), with F using weights sampled at src
    Wall = np.concatenate([skin.Wr[None], skin.W], 0)  # [nb+1, h, w]
    Ms = [np.eye(3)] + [Mw[n] for n in skin.names]
    for _ in range(iters):
        fx = np.zeros_like(X); fy = np.zeros_like(Y)
        for c0 in range(0, len(Ms), 4):
            chunk = Wall[c0:c0 + 4]
            pad = 4 - chunk.shape[0]
            stack = np.concatenate([chunk, np.zeros((pad, h, w), np.float32)], 0) if pad else chunk
            ws = cv2.remap(np.ascontiguousarray(stack.transpose(1, 2, 0)), sx, sy, cv2.INTER_LINEAR,
                           borderMode=cv2.BORDER_REPLICATE)
            if ws.ndim == 2: ws = ws[..., None]
            for j in range(chunk.shape[0]):
                M = Ms[c0 + j]; wj = ws[..., j]
                fx += wj * (M[0, 0] * sx + M[0, 1] * sy + M[0, 2])
                fy += wj * (M[1, 0] * sx + M[1, 1] * sy + M[1, 2])
        sx += (X - fx); sy += (Y - fy)
    return cv2.remap(img, sx, sy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))


# ------------------------------------------------------------------ springs (secondary motion)
class Spring:
    def __init__(self, freq=1.6, damp=0.35):
        self.w = 2 * math.pi * freq; self.z = damp; self.x = 0.0; self.v = 0.0
    def step(self, target, dt):
        for _ in range(4):                              # sub-steps keep it stable at 24 fps
            h = dt / 4
            a = -self.w * self.w * (self.x - target) - 2 * self.z * self.w * self.v
            self.v += a * h; self.x += self.v * h
        return self.x


class ActorState:
    """Per-actor memory between frames: last position and the springs."""
    def __init__(self):
        self.t = None; self.x = self.y = 0.0; self.vx = self.vy = 0.0
        self.sp = {"tail1": Spring(1.5, .32), "tail2": Spring(1.2, .28), "tail3": Spring(1.0, .25),
                   "ear": Spring(2.4, .30), "trunk1": Spring(1.4, .3), "trunk2": Spring(1.1, .28),
                   "head": Spring(2.0, .55)}


def layered_pose(species, st, t, dt, x, y, bob, flip, seed, head_extra, tail_amp, wph, talk, extra=None):
    """Blend the layers into one pose and step the springs. x, y = feet on screen, bob = height above ground."""
    sk = SKELETONS[species]
    sgn = -1.0 if flip else 1.0
    # velocities on screen (feet), positive vx = moving the way the animal faces
    if st.t is not None and 0 < t - st.t < 0.2:
        d = t - st.t
        vx = (x - st.x) / d * sgn; vy = ((y - bob) - st.y) / d
        st.vx += (vx - st.vx) * 0.5; st.vy += (vy - st.vy) * 0.5
    st.t, st.x, st.y = t, x, y - bob
    vx, vy = st.vx, st.vy
    P = {}
    # --- idle layer: breathing chest, slow head drift
    br = math.sin(t * 2 * math.pi / 3.2 + seed)
    P["chest"] = [0.6 * br, 1.0 - 0.004 * br, 1.0 + 0.016 * br]
    head = 1.6 * math.sin(t * 2 * math.pi / 4.3 + seed * 1.3)
    # --- walk layer
    if wph is not None:
        head += 2.2 * math.sin(wph * 2)
        P["chest"][0] += 1.2 * math.sin(wph * 2 + 0.6)
    # --- talk layer: nods with the voice
    head += 5.5 * talk
    # --- look layer (from the shot)
    head += head_extra
    P["head"] = [st.sp["head"].step(head, dt), 1.0, 1.0]
    if "neck" in sk:
        P["neck"] = [0.35 * P["head"][0], 1, 1]; P["head"][0] *= 0.75
    # --- tail chain: idle swish + drag from motion (lags behind, overshoots on stops)
    swish = tail_amp * math.sin(t * 2 * math.pi / 1.7 + seed * 2.1)
    drag = np.clip(-vx * 0.035, -22, 22) + np.clip(vy * 0.02, -16, 16)
    if wph is not None: swish += 6 * math.sin(wph)
    a1 = st.sp["tail1"].step(0.45 * swish + 0.5 * drag, dt)
    a2 = st.sp["tail2"].step(0.6 * swish + 0.8 * drag, dt)
    a3 = st.sp["tail3"].step(0.7 * swish + 0.8 * drag, dt)
    for n, a in (("tail1", a1), ("tail2", a2 - 0.3 * a1), ("tail3", a3 - 0.3 * a2)):
        if n in sk: P[n] = [a, 1, 1]
    # --- ears: flick every few seconds, flop with vertical motion
    flick = 0.0
    ph = (t + seed * 2.7) % 5.3
    if ph < 0.35: flick = 14 * math.sin(ph / 0.35 * math.pi)
    e = st.sp["ear"].step(flick + np.clip(vy * 0.03, -14, 14), dt)
    for n in ("ear", "earL", "earR"):
        if n in sk: P[n] = [e if n != "earR" else 0.8 * e, 1, 1]
    # --- elephant trunk: slow curl + follow-through
    if "trunk1" in sk:
        curl = 6 * math.sin(t * 2 * math.pi / 3.6 + seed) + 6 * talk
        t1 = st.sp["trunk1"].step(curl + np.clip(-vx * 0.02, -10, 10), dt)
        t2 = st.sp["trunk2"].step(1.4 * curl + np.clip(-vx * 0.03, -14, 14), dt)
        P["trunk1"] = [t1, 1, 1]; P["trunk2"] = [t2 - 0.3 * t1, 1, 1]
    for k, v in (extra or {}).items():                 # keyframed clip on top (signature moves)
        if k in sk or k == "chest":
            P.setdefault(k, [0, 1, 1]); P[k] = [P[k][0] + v, P[k][1], P[k][2]]
    return {k: tuple(v) for k, v in P.items()}


# ------------------------------------------------------------------ keyframe timelines (LinearAnimation + KeyFrame + interpolators)
def _bez(x1, y1, x2, y2):
    """Cubic-bezier easing like CSS / Rive interpolators: returns f(u) for u in 0..1."""
    def f(u):
        lo, hi = 0.0, 1.0
        for _ in range(18):                              # solve x(t) = u by bisection
            m = (lo + hi) / 2
            x = 3 * (1 - m) ** 2 * m * x1 + 3 * (1 - m) * m * m * x2 + m ** 3
            if x < u: lo = m
            else: hi = m
        m = (lo + hi) / 2
        return 3 * (1 - m) ** 2 * m * y1 + 3 * (1 - m) * m * m * y2 + m ** 3
    return f
EASE = {"linear": lambda u: u, "inout": _bez(.42, 0, .58, 1), "out": _bez(0, 0, .58, 1), "in": _bez(.42, 0, 1, 1),
        "back": _bez(.34, 1.45, .64, 1), "hold": lambda u: 0.0}


class Clip:
    """tracks: {channel: [(time, value, easing_into_this_key), ...]}. Channels are bone names (degrees, added to the
    pose) or root channels: 'bob' (fraction of height, up), 'rot' (deg), 'sq' (squash, 1 = none), 'lift' (front leg)."""
    def __init__(self, duration, tracks):
        self.d = duration; self.tracks = {k: sorted(v) for k, v in tracks.items()}
    def sample(self, t):
        out = {}
        for ch, keys in self.tracks.items():
            if t <= keys[0][0]: out[ch] = keys[0][1]; continue
            if t >= keys[-1][0]: out[ch] = keys[-1][1]; continue
            for (t0, v0, _), (t1, v1, e) in zip(keys, keys[1:]):
                if t0 <= t <= t1:
                    u = (t - t0) / max(1e-6, t1 - t0); out[ch] = v0 + (v1 - v0) * EASE[e](u); break
        return out


def K(*pairs, e="inout"):
    """Compact track: K(0,0, .3,-6, .6,6) -> [(0,0),(0.3,-6),(0.6,6)] with one easing."""
    return [(pairs[i], pairs[i + 1], e) for i in range(0, len(pairs), 2)]


# One signature move per animal (gentle: under 2.2 s, no fast spins, no flashes).
SIGNATURE = {
 "lion": Clip(2.0, {   # chest out, a proud slow mane shake, tail swish
    "chest": K(0, 0, .4, -4, 1.6, -4, 2.0, 0), "bob": K(0, 0, .4, .025, 1.6, .025, 2.0, 0),
    "head": K(0, 0, .45, -5, .75, 5, 1.05, -4, 1.35, 3, 1.7, 0),
    "tail2": K(0, 0, .5, 10, 1.0, -7, 1.5, 4, 2.0, 0), "tail3": K(0, 0, .6, 12, 1.1, -9, 1.6, 5, 2.0, 0)}),
 "queen": Clip(2.0, {  # graceful head tilt up, ear flick, tail curl
    "neck": K(0, 0, .5, -6, 1.4, -6, 2.0, 0), "head": K(0, 0, .5, -8, 1.4, -8, 2.0, 0),
    "ear": K(0, 0, .6, 0, .7, -16, .85, 0, e="out"),
    "tail3": K(0, 0, .6, -22, 1.4, -22, 2.0, 0), "tail2": K(0, 0, .6, -10, 1.4, -10, 2.0, 0)}),
 "ele": Clip(2.2, {    # trunk rises in a slow curl, ears flap three times
    "head": K(0, 0, .5, -5, 1.6, -5, 2.2, 0),
    "trunk1": K(0, 0, .6, -28, 1.6, -28, 2.2, 0), "trunk2": K(0, 0, .7, -40, 1.6, -40, 2.2, 0),
    "ear": K(0, 0, .35, 12, .7, -4, 1.05, 12, 1.4, -4, 1.75, 10, 2.2, 0)}),
 "roo": Clip(1.8, {    # ears twitch one after the other, tail thump, little crouch
    "earL": K(0, 0, .2, -10, .4, 0, e="out"), "earR": K(0, 0, .35, 0, .55, 8, .75, 0, e="out"),
    "sq": K(0, 1, .9, .94, 1.15, 1.03, 1.4, 1), "tail1": K(0, 0, .9, 8, 1.1, -6, 1.4, 0),
    "head": K(0, 0, 1.2, -4, 1.8, 0)}),
 "horse": Clip(2.0, {  # head toss and a front-hoof paw
    "neck": K(0, 0, .4, -9, .8, 4, 1.2, 0), "head": K(0, 0, .4, -7, .8, 6, 1.2, 0),
    "lift": K(0, 0, 1.1, 0, 1.35, 1, 1.6, 0, 1.75, .7, 1.95, 0),
    "tail2": K(0, 0, .5, 10, 1.0, -8, 1.5, 0), "tail3": K(0, 0, .6, 16, 1.1, -12, 1.6, 0)}),
 "sq": Clip(1.8, {     # big tail fluff wave, quick head tilt
    "tail1": K(0, 0, .3, -6, .7, 5, 1.1, -3, 1.5, 0), "tail2": K(0, 0, .4, -9, .8, 7, 1.2, -4, 1.6, 0),
    "tail3": K(0, 0, .5, -12, .9, 10, 1.3, -5, 1.8, 0),
    "head": K(0, 0, .3, -8, .9, -8, 1.3, 0), "sq": K(0, 1, .2, .96, .4, 1.02, .6, 1)}),
}

# Walk cycle (keyframed over one stride, phase 0..2pi): knees bend on the forward swing, the body dips twice.
def leg_pose(phase_sign, wph, amp=16.0, knee=34.0):
    """Thigh and shin angles for one leg. phase_sign = +1/-1 picks the diagonal pair."""
    th = phase_sign * amp * math.sin(wph)
    forward = max(0.0, -phase_sign * math.cos(wph))       # leg moving forward = lifted
    return th, knee * forward ** 1.4


class LegSkin:
    """Two bones (thigh, shin) for one cut-out leg layer: weights by height around the knee."""
    def __init__(self, w, h, hip, knee_y):
        self.names = ["thigh", "shin"]; self.w, self.h = w, h
        self.sk = {"thigh": ("root",), "shin": ("thigh",)}
        Y = (np.arange(h, dtype=np.float32) + .5)[:, None] * np.ones((1, w), np.float32)
        band = max(4.0, 0.10 * h)
        shin = np.clip((Y - knee_y + band) / (2 * band), 0, 1); shin = shin * shin * (3 - 2 * shin)
        top = np.clip((Y - hip[1]) / max(2.0, 0.12 * h), 0, 1)     # the hip overlap stays with the body
        self.Wr = (1 - top).astype(np.float32)
        self.W = np.stack([top * (1 - shin), top * shin]).astype(np.float32)
        self.px = {"thigh": hip, "shin": (hip[0], knee_y)}
