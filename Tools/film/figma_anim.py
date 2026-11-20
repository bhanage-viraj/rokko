"""Generate the use_figma scripts: (1) build each animal's rig from the layer images dropped into Figma,
(2) write its hand-keyed timeline (Figma manual keyframes). The same tracks are saved as JSON for the
film runtime, so Figma and the film always play the same animation.

Timeline per animal (seconds): idle 0-3.2 | walk 3.2-5.4 | hop 5.4-6.8 | signature 6.8-9.0
Figma ROTATION is counter-clockwise positive (degrees); TRANSLATION in px of the 1024 frame.
"""
import json, math
import rokkorig as RR

SEG = {"idle": (0.0, 3.2), "walk": (3.2, 5.4), "hop": (5.4, 6.8), "sig": (6.8, 9.0)}
DUR = 9.0
STRIDE = 1.1
WALKERS = {"lion", "queen", "ele", "horse"}
HOPPERS = {"roo", "horse"}
LEG_SIGN = {"hindNear": 1, "frontFar": 1, "hindFar": -1, "frontNear": -1}


class Tracks:
    def __init__(self): self.t = {}
    def add(self, bone, field, t, v, ease="EASE_IN_AND_OUT"):
        self.t.setdefault(bone, {}).setdefault(field, {})[round(t, 3)] = (round(v, 3), ease)
    def out(self):
        res = {}
        for b, fs in self.t.items():
            res[b] = {}
            for f, keys in fs.items():
                res[b][f] = [{"t": t, "v": v, "e": e} for t, (v, e) in sorted(keys.items())]
        return res


def build_tracks(sp, layers):
    T = Tracks(); has = set(layers)
    # breathing on the whole character (scale from the feet), all through
    for i in range(0, 6):        # breathing, except where the hop or the signature squash the body
        t = i * 1.6
        busy = (sp in HOPPERS and SEG["hop"][0] <= t <= SEG["hop"][1]) or ("sq" in RR.SIGNATURE[sp].tracks and SEG["sig"][0] <= t <= SEG["sig"][1])
        if t <= DUR and not busy: T.add("body", "SCALE_Y", t, 1.0 if i % 2 == 0 else 1.012)
    T.add("body", "SCALE_Y", DUR, 1.0)
    # head: slow look-around in idle, nods while walking
    hb = "head"
    for t, v in ((0, 0), (1.1, 1.6), (2.2, -1.0), (3.2, 0)): T.add(hb, "ROTATION", t, v)
    # tail: overlapping swish all the time (each piece a little later and larger)
    tails = [n for n in ("tail1", "tail2", "tail3") if n in has]
    for k, n in enumerate(tails):
        amp = (4, 6, 8)[k] if sp != "sq" else (3, 4.5, 6)[k]
        lag = 0.18 * k
        tt = 0.0; i = 0
        while tt <= DUR + 1e-6:
            v = amp * math.sin(2 * math.pi * (tt - lag) / 1.6)
            T.add(n, "ROTATION", tt, v); i += 1; tt = i * 0.4
    # ears flick twice
    for n in ("ear", "earL", "earR"):
        if n in has:
            for t0 in (1.3, 7.9):
                T.add(n, "ROTATION", t0, 0); T.add(n, "ROTATION", t0 + 0.15, 12 if n != "earR" else 9, "EASE_OUT"); T.add(n, "ROTATION", t0 + 0.4, 0)
    # ---- walk (keyed stride: 8 keys per stride, eased in and out)
    a, b = SEG["walk"]
    if sp in WALKERS:
        n = int(round((b - a) / STRIDE * 8))
        for i in range(n + 1):
            t = a + (b - a) * i / n; ph = 2 * math.pi * (t - a) / STRIDE
            env = min(1.0, (t - a) / 0.25, (b - t) / 0.25) if 0 < t - a < b - a else 0.0
            for leg, sgn in LEG_SIGN.items():
                if leg + "Thigh" not in has: continue
                th, kn = RR.leg_pose(sgn, ph, amp=15.0, knee=32.0)
                T.add(leg + "Thigh", "ROTATION", t, -th * env, "LINEAR")
                T.add(leg + "Shin", "ROTATION", t, -kn * env, "LINEAR")
            T.add("body", "TRANSLATION_Y", t, -5 * abs(math.sin(ph)) * env, "LINEAR")
            T.add(hb, "ROTATION", t, -2.0 * math.sin(2 * ph) * env, "LINEAR")
    else:      # roo / squirrel: little weight shifts instead of a walk
        for t, v in ((a, 0), (a + 0.55, -2), (a + 1.1, 1.5), (b, 0)): T.add(hb, "ROTATION", t, v)
    # ---- hop
    a, b = SEG["hop"]
    if sp in HOPPERS:
        d = b - a; c1, c2 = a + 0.18 * d, a + 0.80 * d
        T.add("body", "TRANSLATION_Y", a, 0); T.add("body", "TRANSLATION_Y", c1, 10, "EASE_OUT")
        T.add("body", "TRANSLATION_Y", (c1 + c2) / 2, -150, "EASE_OUT"); T.add("body", "TRANSLATION_Y", c2, 0, "EASE_IN")
        T.add("body", "TRANSLATION_Y", b, 0)
        T.add("body", "ROTATION", a, 0); T.add("body", "ROTATION", c1, 0); T.add("body", "ROTATION", (c1 + c2) / 2, 6); T.add("body", "ROTATION", c2, 0)
        T.add("body", "SCALE_Y", a + 0.001, 1.0); T.add("body", "SCALE_Y", c1, 0.92, "EASE_OUT"); T.add("body", "SCALE_Y", c1 + 0.12, 1.04)
        T.add("body", "SCALE_Y", c2, 1.0); T.add("body", "SCALE_Y", c2 + 0.1, 0.94, "EASE_OUT"); T.add("body", "SCALE_Y", b, 1.0)
        mid = (c1 + c2) / 2
        if sp == "horse":
            for leg, (th, kn) in {"frontNear": (22, -60), "frontFar": (22, -60), "hindNear": (-24, -12), "hindFar": (-24, -12)}.items():
                for t, k in ((a, 0), (c1, 0.3), (mid, 1), (c2, 0.2), (b, 0)):
                    T.add(leg + "Thigh", "ROTATION", t, th * k); T.add(leg + "Shin", "ROTATION", t, kn * k)
        if sp == "roo":
            for t, k in ((a, 0), (c1, -0.6), (mid, 1), (c2, 0), (b, 0)):
                T.add("thigh", "ROTATION", t, 10 * k); T.add("foot", "ROTATION", t, -16 * max(k, 0) + 8 * min(k, 0))
            for t, k in ((a, 0), (mid, 1), (b, 0)): T.add("tail1", "ROTATION", t, 10 * k)
    # ---- signature (from rokkorig.SIGNATURE, converted to Figma terms)
    a, b = SEG["sig"]
    clip = RR.SIGNATURE[sp]
    chans = set(clip.tracks)
    steps = int(clip.d / 0.1)
    for i in range(steps + 1):
        lt = clip.d * i / steps; t = a + lt; v = clip.sample(lt)
        for ch, val in v.items():
            if ch == "bob": T.add("body", "TRANSLATION_Y", t, -val * 800, "LINEAR")
            elif ch == "sq": T.add("body", "SCALE_Y", t, val, "LINEAR")
            elif ch == "rot": T.add("body", "ROTATION", t, -val, "LINEAR")
            elif ch == "lift":
                if "frontNearThigh" in has:
                    T.add("frontNearThigh", "ROTATION", t, 18 * val, "LINEAR"); T.add("frontNearShin", "ROTATION", t, -48 * val, "LINEAR")
            elif ch == "chest": continue
            elif ch in has: T.add(ch, "ROTATION", t, -val, "LINEAR")
    # pin rest values at segment edges for every bone that moves inside a segment
    out = T.out()
    for bone, fs in out.items():
        for f, keys in fs.items():
            rest = 1.0 if f.startswith("SCALE") else 0.0
            times = {k["t"] for k in keys}
            for s0, s1 in SEG.values():
                inside = [k for k in keys if s0 < k["t"] < s1]
                if inside:
                    for e in (s0, s1):
                        if e not in times and not (f == "ROTATION" and bone.startswith("tail")) and not (bone == "body" and f == "SCALE_Y"):
                            keys.append({"t": e, "v": rest, "e": "EASE_IN_AND_OUT"})
            keys.sort(key=lambda k: k["t"])
    return out


def rig_tree(rig):
    L = {l["name"]: l for l in rig["layers"]}; z = {l["name"]: i for i, l in enumerate(rig["layers"])}
    kids = {}
    for l in rig["layers"]:
        if l["parent"]: kids.setdefault(l["parent"], []).append(l["name"])
    def node(n):
        items = [(z[n], {"rect": n, "x": L[n]["x"], "y": L[n]["y"], "w": L[n]["w"], "h": L[n]["h"]})]
        for c in kids.get(n, []): items.append((z[c], node(c)))
        items.sort(key=lambda t: t[0])
        return {"bone": n, "px": round(L[n]["pivot"][0], 1), "py": round(L[n]["pivot"][1], 1), "items": [i for _, i in items]}
    return node("body")


TITLES = {"lion_c": "Lion King · Sunrise", "queen_c": "Lioness Queen · Sunrise", "ele_c": "Elephant · Sunrise",
          "roo_c": "Kangaroo · Sunrise", "horse_c": "Horse · Sunrise", "sq_c": "Squirrel · Sunrise"}


def build_js(keys):
    data = {}
    for k in keys:
        rig = json.load(open(f"parts/{k}.rig.json"))
        data[k] = {"title": TITLES[k], "tree": rig_tree(rig)}
    return f"""const DATA = {json.dumps(data, separators=(',', ':'))};
const R = 700; const out = {{}};
const page = figma.currentPage;
// the dropped layer images, by name (with or without .png)
const imgs = {{}};
for (const n of page.findAll(n => /__/.test(n.name) && "fills" in n)) {{
  const f = (n.fills || []).find(p => p.type === "IMAGE"); if (!f) continue;
  imgs[n.name.replace(/\\.png$/, "")] = {{ node: n, hash: f.imageHash }};
}}
let col = 0;
for (const key of Object.keys(DATA)) {{
  const d = DATA[key]; const ids = {{}}; const missing = [];
  const art = figma.createFrame(); art.name = d.title; art.resize(1024, 1024); art.x = 2400 + col * 1100; art.y = 0; col++;
  art.fills = [{{ type: "SOLID", color: {{ r: 0.957, g: 0.941, b: 0.89 }} }}]; art.clipsContent = true;
  function build(n, parent, pax, pay) {{
    const f = figma.createFrame(); f.name = "bone · " + n.bone; f.resize(2 * R, 2 * R);
    const ax = n.px - R, ay = n.py - R; f.x = ax - pax; f.y = ay - pay; f.fills = []; f.clipsContent = false;
    parent.appendChild(f); ids[n.bone] = f.id;
    for (const it of n.items) {{
      if (it.rect) {{
        const im = imgs[key + "__" + it.rect]; if (!im) {{ missing.push(it.rect); continue; }}
        const r = figma.createRectangle(); r.name = it.rect; r.resize(it.w, it.h); r.x = it.x - ax; r.y = it.y - ay;
        r.fills = [{{ type: "IMAGE", imageHash: im.hash, scaleMode: "FILL" }}]; f.appendChild(r);
      }} else build(it, f, ax, ay);
    }}
  }}
  build(d.tree, art, 0, 0);
  out[key] = {{ artboard: art.id, bones: ids, missing }};
}}
return out;"""


def keyframes_js(key, bone_ids):
    rig = json.load(open(f"parts/{key}.rig.json")); sp = rig["species"]
    tracks = build_tracks(sp, [l["name"] for l in rig["layers"]])
    json.dump(tracks, open(f"parts/{key}.tracks.json", "w"))
    E = {"LINEAR": "L", "EASE_IN_AND_OUT": "I", "EASE_OUT": "O", "EASE_IN": "N"}
    comp = {b: {f: [[k["t"], k["v"], E[k["e"]]] for k in ks] for f, ks in fs.items()} for b, fs in tracks.items()}
    return f"""const TR = {json.dumps(comp, separators=(',', ':'))};
const EZ = {{ L: "LINEAR", I: "EASE_IN_AND_OUT", O: "EASE_OUT", N: "EASE_IN" }};
const IDS = {json.dumps(bone_ids)};
const done = []; const errors = [];
for (const bone of Object.keys(TR)) {{
  const node = await figma.getNodeByIdAsync(IDS[bone]); if (!node) {{ errors.push("no node " + bone); continue; }}
  for (const field of Object.keys(TR[bone])) {{
    const keys = TR[bone][field].map((k, i) => ({{ timelinePosition: k[0], value: {{ type: "FLOAT", value: k[1] }}, ...(i ? {{ easing: {{ type: EZ[k[2]] }} }} : {{}}) }}));
    try {{ node.applyManualKeyframeTrack({{ type: "PROPERTY", name: field }}, {{ keyframes: keys }}); done.push(bone + "." + field); }}
    catch (e) {{ errors.push(bone + "." + field + ": " + String(e)); }}
  }}
}}
const any = await figma.getNodeByIdAsync(IDS["body"]);
const [tl] = any.timelines; if (tl && tl.duration < {DUR}) any.setTimelineDuration(tl.id, {DUR});
return {{ mutatedNodeIds: Object.values(IDS), done: done.length, errors, timelines: any.timelines }};"""


if __name__ == "__main__":
    import sys
    keys = ["lion_c", "queen_c", "ele_c", "roo_c", "horse_c", "sq_c"]
    s = build_js(keys); open("parts/build_all.figma.js", "w").write(s); print("build js", len(s))
    for k in keys:
        rig = json.load(open(f"parts/{k}.rig.json"))
        tr = build_tracks(rig["species"], [l["name"] for l in rig["layers"]])
        print(k, {b: list(f) for b, f in tr.items()}, sum(len(v) for f in tr.values() for v in f.values()), "keys")
