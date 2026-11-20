"""Split each original character picture into rig layers along its skeleton (no redrawing):
legs (thigh + shin, traced as shapes), tail pieces, head / neck / ears / trunk, body. Joints get a hidden
underlay (the lower layer continues 22 px under the upper one) and a soft 14 px feathered edge on the upper
layer, so rotating a joint never shows a seam. Writes full-res layers (runtime) and small previews (Figma)."""
import json, os, io, base64
import numpy as np
import cv2
from PIL import Image
import render5 as R
import rokkorig as RR

# z order (low -> high) and parent of every layer, per species; legs are added from LEG_RIGS
SPEC = {
 "lion":  {"regions_d": [("head", "ellipse", (.625, .44, .29, .27)), ("head", "box", (.48, .04, .68, .25)), ("tail3", "ellipse", (.17, .52, .07, .09))],
          "regions": [("head", "ellipse", (.635, .445, .275, .255)), ("head", "box", (.50, .06, .68, .25)), ("tail3", "ellipse", (.19, .535, .065, .085))],
           "groups": {"tail1": ["tail1"], "tail2": ["tail2"], "tail3": ["tail3"], "head": ["head", "earL", "earR"]},
           "parent": {"tail1": "body", "tail2": "tail1", "tail3": "tail2", "head": "body"},
           "z": ["tail1", "tail2", "tail3", "FAR", "body", "NEAR", "head"]},
 "queen": {"regions_d": [("neck", "box", (.60, .32, .75, .56)), ("head", "ellipse", (.70, .25, .16, .13)), ("ear", "ellipse", (.575, .235, .05, .06))],
          "regions": [("neck", "box", (.58, .30, .74, .52)), ("head", "ellipse", (.70, .265, .145, .13)), ("ear", "ellipse", (.575, .24, .05, .06))],
           "groups": {"tail1": ["tail1"], "tail2": ["tail2"], "tail3": ["tail3"], "neck": ["neck"], "head": ["head"], "ear": ["ear"]},
           "parent": {"tail1": "body", "tail2": "tail1", "tail3": "tail2", "neck": "body", "head": "neck", "ear": "head"},
           "z": ["tail1", "tail2", "tail3", "FAR", "body", "NEAR", "neck", "head", "ear"]},
 "horse": {"regions_d": [("neck", "box", (.40, .12, .70, .55)), ("head", "ellipse", (.77, .29, .135, .14))],
          "regions": [("neck", "box", (.40, .12, .68, .52)), ("head", "ellipse", (.765, .285, .125, .14))],
           "groups": {"tail1": ["tail1"], "tail2": ["tail2"], "tail3": ["tail3"], "neck": ["neck"], "head": ["head", "ear"]},
           "parent": {"tail1": "body", "tail2": "tail1", "tail3": "tail2", "neck": "body", "head": "neck"},
           "z": ["tail1", "tail2", "tail3", "FAR", "body", "NEAR", "neck", "head"]},
 "ele":   {"regions_d": [("head", "ellipse", (.75, .40, .19, .21)), ("ear", "ellipse", (.46, .42, .10, .16)), ("trunk1", "box", (.70, .52, .83, .66)), ("trunk2", "box", (.80, .56, .95, .73)), ("body", "box", (.42, .10, .62, .28))],
          "regions": [("head", "ellipse", (.73, .43, .18, .21)), ("ear", "ellipse", (.455, .41, .105, .175)),
                       ("trunk1", "box", (.80, .53, .97, .645)), ("trunk2", "box", (.83, .645, .97, .76)), ("body", "box", (.42, .10, .63, .275))],
           "groups": {"tail1": ["tail1"], "tail2": ["tail2"], "head": ["head"], "ear": ["ear"], "trunk1": ["trunk1"], "trunk2": ["trunk2"]},
           "parent": {"tail1": "body", "tail2": "tail1", "head": "body", "ear": "head", "trunk1": "head", "trunk2": "trunk1"},
           "z": ["tail1", "tail2", "FAR", "body", "NEAR", "head", "trunk1", "trunk2", "ear"]},
 "roo":   {"regions_d": [("neck", "box", (.59, .38, .74, .52)), ("head", "ellipse", (.69, .345, .12, .085)), ("earL", "box", (.40, .12, .585, .35)), ("earR", "box", (.56, .11, .68, .31)), ("thigh", "ellipse", (.55, .68, .10, .13)), ("foot", "box", (.45, .79, .78, .89)), ("tail1", "box", (.30, .68, .45, .90)), ("tail2", "box", (.17, .68, .31, .90)), ("tail3", "box", (0, .60, .20, .90))],
          "regions": [("neck", "box", (.57, .37, .72, .50)), ("head", "ellipse", (.675, .32, .125, .09)),
                       ("earL", "box", (.39, .08, .555, .335)), ("earR", "box", (.535, .08, .635, .29)),
                       ("thigh", "ellipse", (.535, .675, .095, .135)), ("foot", "box", (.45, .79, .76, .90)),
                       ("tail1", "box", (.30, .66, .455, .90)), ("tail2", "box", (.14, .68, .30, .90)), ("tail3", "box", (0, .55, .14, .90))],
           "groups": {"tail1": ["tail1"], "tail2": ["tail2"], "tail3": ["tail3"], "thigh": ["thigh"], "foot": ["foot"],
                      "neck": ["neck"], "head": ["head"], "earL": ["earL"], "earR": ["earR"]},
           "parent": {"tail1": "body", "tail2": "tail1", "tail3": "tail2", "thigh": "body", "foot": "thigh", "neck": "body",
                      "head": "neck", "earL": "head", "earR": "head"},
           "z": ["tail3", "tail2", "tail1", "body", "thigh", "foot", "neck", "head", "earR", "earL"]},
 "sq":    {"regions_d": [("tail1", "box", (.36, .55, .50, .87)), ("tail2", "box", (.10, .50, .37, .87)), ("tail3", "box", (.08, .25, .48, .52)), ("head", "ellipse", (.68, .37, .17, .19))],
          "regions": [("tail1", "box", (.42, .55, .585, .86)), ("tail2", "box", (.20, .44, .44, .86)), ("tail3", "box", (0, .22, .42, .60)),
                       ("head", "ellipse", (.785, .40, .165, .23))],
           "groups": {"tail1": ["tail1"], "tail2": ["tail2"], "tail3": ["tail3"], "head": ["head"]},
           "parent": {"tail1": "body", "tail2": "tail1", "tail3": "tail2", "head": "body"},
           "z": ["tail3", "tail2", "tail1", "body", "head"]},
}
LEG_NAMES = {"nb": "hindNear", "fb": "hindFar", "nf": "frontNear", "ff": "frontFar"}


def build(key, out_dir, preview_scale=0.3):
    sp = key.split("_")[0]; spec = SPEC[sp]
    ch = R.C[key]; bx0, by0, bx1, by1 = ch.bbox
    op = np.array(ch.full); cl = np.array(ch.full)
    if ch.img_closed is not ch.img: cl[by0:by1, bx0:bx1] = np.array(ch.img_closed)
    H, W = op.shape[:2]
    alpha = op[..., 3] > 12
    sk = RR.Skin(sp, W, H, None, legs_separate=key in R.LEG_RIGS)
    # --- label every opaque pixel
    names = ["body"] + list(spec["groups"])
    wmap = np.zeros((len(names), H, W), np.float32); wmap[0] = sk.Wr
    for gi, (g, bones) in enumerate(spec["groups"].items(), 1):
        for b in bones:
            if b in sk.names: wmap[gi] += sk.W[sk.names.index(b)]
    for b in ("chest",) + (("neck",) if "neck" not in spec["groups"] else ()):
        if b in sk.names: wmap[0] += sk.W[sk.names.index(b)]
    lab = np.where(alpha, wmap.argmax(0), -1).astype(np.int32)
    Yf, Xf = np.mgrid[0:H, 0:W] / 1024.0
    regions = spec.get("regions_d", spec.get("regions", [])) if key.endswith("_d") else spec.get("regions", [])
    for g, shape, (a1, a2, a3, a4) in regions:
        m = (((Xf - a1) / a3) ** 2 + ((Yf - a2) / a4) ** 2 <= 1) if shape == "ellipse" else ((Xf >= a1) & (Xf <= a3) & (Yf >= a2) & (Yf <= a4))
        lab[m & alpha] = names.index(g)
    parent = dict(spec["parent"]); z = []; pivots = {}
    for gi, g in enumerate(names):
        if g == "body": pivots[g] = (float((bx0 + bx1) / 2), float(by1 - 4))
        else:
            b = spec["groups"][g][0]; pivots[g] = tuple(float(v) * 1024 for v in RR.SKELETONS[sp][b][1])
    # legs: traced ownership + knee split
    legs = []
    if key in R.LEG_RIGS:
        R._rig_parts(key); owner = R._owner_maps[key]
        for i, (x0, x1, cut, kind) in enumerate(R.LEG_RIGS[key]):
            m = (owner == i) & alpha
            if not m.any(): continue
            ys, xs = np.where(m); top, bot = ys.min(), ys.max()
            hip = (float(xs[ys < top + 30].mean()), float(cut - 8)); knee_y = hip[1] + 0.5 * (bot - hip[1])
            knee_x = float(xs[(ys > knee_y - 8) & (ys < knee_y + 8)].mean()) if ((ys > knee_y - 8) & (ys < knee_y + 8)).any() else hip[0]
            nm = LEG_NAMES[kind]; th, sh = nm + "Thigh", nm + "Shin"
            names += [th, sh]; Yg = np.arange(H)[:, None]
            lab[m & (Yg < knee_y)] = len(names) - 2; lab[m & (Yg >= knee_y)] = len(names) - 1
            parent[th] = "body"; parent[sh] = th
            pivots[th] = hip; pivots[sh] = (knee_x, knee_y)
            legs.append((kind, th, sh))
    # z order
    for item in spec["z"]:
        if item in ("FAR", "NEAR"):
            for kind, th, sh in legs:
                if (kind in ("fb", "ff")) == (item == "FAR"): z += [th, sh]
        else: z.append(item)
    z = [n for n in z if n in names]
    zi = {n: i for i, n in enumerate(z)}
    # --- layers with underlay + feather toward the parent
    layers = []
    for n in z:
        idx = names.index(n)
        core = lab == idx
        if not core.any(): continue
        d = cv2.distanceTransform((~core).astype(np.uint8), cv2.DIST_L2, 5)
        a = core.astype(np.float32)
        rel = [parent.get(n)] + [c for c, p in parent.items() if p == n]
        for q in rel:
            if q is None or q not in names: continue
            qm = lab == names.index(q)
            if zi.get(q, -1) > zi[n]:      # q is drawn over me: continue 22 px under it
                a = np.maximum(a, (qm & (d < 22)).astype(np.float32))
            else:                           # I am drawn over q: soft 14 px edge into it
                a = np.maximum(a, qm * np.clip(1 - d / 14.0, 0, 1))
        for src, tag in ((op, "open"), (cl, "closed")):
            if tag == "closed" and n not in ("head",): continue
            img = src.copy(); img[..., 3] = (src[..., 3].astype(np.float32) * a).astype(np.uint8)
            ys, xs = np.where(img[..., 3] > 2)
            if not len(ys): continue
            x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
            Image.fromarray(img[y0:y1, x0:x1]).save(f"{out_dir}/{key}__{n}{'_closed' if tag == 'closed' else ''}.png")
            if tag == "open":
                layers.append({"name": n, "parent": parent.get(n), "pivot": pivots[n], "x": int(x0), "y": int(y0), "w": int(x1 - x0), "h": int(y1 - y0)})
    have = {l["name"] for l in layers}
    for l in layers:                                   # a missing parent layer: hang from the next one up
        p = l["parent"]
        while p is not None and p not in have: p = parent.get(p)
        l["parent"] = p
    rig = {"key": key, "species": sp, "bbox": [int(bx0), int(by0), int(bx1), int(by1)], "layers": layers}
    json.dump(rig, open(f"{out_dir}/{key}.rig.json", "w"), indent=1)
    return rig


def preview_b64(key, out_dir, scale=0.24, colors=64):
    """Small palette PNGs (base64) of every layer, for building the rig in Figma."""
    rig = json.load(open(f"{out_dir}/{key}.rig.json")); res = {}
    for L in rig["layers"]:
        for suf in ("",):
            p = f"{out_dir}/{key}__{L['name']}{suf}.png"
            if not os.path.exists(p): continue
            im = Image.open(p); im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
            q = im.quantize(colors, method=Image.Quantize.FASTOCTREE)
            b = io.BytesIO(); q.save(b, "PNG", optimize=True); res[L["name"] + suf] = base64.b64encode(b.getvalue()).decode()
    return res


if __name__ == "__main__":
    import sys
    os.makedirs("parts", exist_ok=True)
    for k in sys.argv[1:]:
        rig = build(k, "parts"); pv = preview_b64(k, "parts")
        print(k, [l["name"] for l in rig["layers"]], "preview bytes", sum(len(v) for v in pv.values()))
