"""Generates Werecat's layered character + UI art as SVG, then renders PNGs.

Run from the repo root:  python3 tools/gen_art.py
Needs: rsvg-convert (librsvg).  Output: assets/sprites/*.png

All werecat layers share one 800x800 canvas so they stack in Godot with no
offsets. Mantis-arm segments are separate small canvases with known pivots
(see ARM_PIVOTS) so the game can animate them.

Style: bold plum outline (Cult-of-the-Lamb-ish), soft painted gradients,
clipped shading, rim light on the scary layers. Tween-safe: no blood.
"""
import math
import os
import random
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
TMP = os.path.join(ROOT, "tools", "build")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

W = 800
HC = (400, 380)          # head center
INK = "#241226"          # outline
OUTLINE = 7

# Cute palette
FUR = "#E9B98A"
FUR_LIGHT = "#FFE6C7"
FUR_SHADOW = "#BF845A"
CREAM = "#FFF4E4"
CREAM_SHADOW = "#EBCDB0"
PINK = "#F7A3BE"
PINK_DEEP = "#E36F95"
# Scary palette
SFUR = "#2F2230"
SFUR_LIGHT = "#4E3A4C"
SFUR_SHADOW = "#120A12"
EMBER = "#FF5A2E"
EMBER_HOT = "#FFC04A"
ICHOR = "#A8FF6A"
MANTIS = "#4C6630"
MANTIS_LIGHT = "#8AA85A"
MANTIS_SHADOW = "#1C2A12"
BONE = "#F2EAD0"

ARM_PIVOTS = {
    # name: (canvas w, h, pivot x, y, distal joint x, y)
    "arm_coxa": (170, 80, 30, 40, 140, 40),
    "arm_femur": (320, 110, 30, 50, 290, 50),
    "arm_tibia": (260, 110, 24, 40, 236, 40),
}


def mirror_x(pts):
    return [(W - x, y) for x, y in pts]


def f(v):
    return f"{v:.1f}"


def render(name, body, defs="", w=W, h=W):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
           f'viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>')
    sp = os.path.join(TMP, name + ".svg")
    with open(sp, "w") as fh:
        fh.write(svg)
    subprocess.run(["rsvg-convert", "-o", os.path.join(OUT, name + ".png"), sp], check=True)


# ------------------------------------------------------------------ shapes

def fluffy(cx, cy, rx, ry, n, length, seed, droop=0.35, bulge=0.18, sharp=0.25, start=-math.pi / 2):
    """Closed path of swept fur tufts around an ellipse.
    length(theta) -> tuft length. Tips droop with gravity."""
    rnd = random.Random(seed)
    step = 2 * math.pi / n
    valleys, tips = [], []
    for i in range(n):
        a = start + i * step
        valleys.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry, a))
    for i in range(n):
        a = start + (i + 0.5) * step + rnd.uniform(-0.12, 0.12) * step
        L = length(a) * rnd.uniform(0.75, 1.25)
        r = 1.0 + L / ((rx + ry) / 2)
        tx = cx + math.cos(a) * rx * r
        ty = cy + math.sin(a) * ry * r + droop * L
        tips.append((tx, ty, a, L))
    d = f"M {f(valleys[0][0])} {f(valleys[0][1])} "
    for i in range(n):
        vx, vy, va = valleys[i]
        nx_, ny_, na = valleys[(i + 1) % n]
        tx, ty, ta, L = tips[i]
        # outward push for valley controls
        ox, oy = math.cos(va), math.sin(va)
        c1 = (vx + ox * L * bulge + math.cos(va + math.pi / 2) * L * 0.25,
              vy + oy * L * bulge + math.sin(va + math.pi / 2) * L * 0.25)
        c2 = (tx - (tx - vx) * sharp, ty - (ty - vy) * sharp * 0.4)
        d += f"C {f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(tx)} {f(ty)} "
        ox2, oy2 = math.cos(na), math.sin(na)
        c3 = (tx - (tx - nx_) * sharp, ty - (ty - ny_) * sharp)
        c4 = (nx_ + ox2 * L * bulge * 0.6, ny_ + oy2 * L * bulge * 0.6)
        d += f"C {f(c3[0])} {f(c3[1])} {f(c4[0])} {f(c4[1])} {f(nx_)} {f(ny_)} "
    return d + "Z", tips


def strands(tips, cx, cy, color, width, opacity, seed, inward=0.55):
    """Short fur strokes pointing out toward each tuft tip, for texture."""
    rnd = random.Random(seed)
    out = ""
    for tx, ty, a, L in tips:
        for k in range(2):
            j = rnd.uniform(-0.12, 0.12)
            sx = cx + (tx - cx) * (0.70 + rnd.uniform(-0.05, 0.04)) + math.cos(a + math.pi / 2) * j * 60
            sy = cy + (ty - cy) * (0.70 + rnd.uniform(-0.05, 0.04)) + math.sin(a + math.pi / 2) * j * 60
            ex = sx + (tx - sx) * inward
            ey = sy + (ty - sy) * inward
            mx = (sx + ex) / 2 + math.cos(a + math.pi / 2) * 6
            my = (sy + ey) / 2 + math.sin(a + math.pi / 2) * 6
            out += (f'<path d="M {f(sx)} {f(sy)} Q {f(mx)} {f(my)} {f(ex)} {f(ey)}" fill="none" '
                    f'stroke="{color}" stroke-width="{width}" stroke-linecap="round" opacity="{opacity}"/>')
    return out


def blur_filter(fid, sd):
    return (f'<filter id="{fid}" x="-50%" y="-50%" width="200%" height="200%">'
            f'<feGaussianBlur stdDeviation="{sd}"/></filter>')


def radial(gid, stops, cx="50%", cy="50%", r="50%", fx=None, fy=None):
    fx = fx or cx
    fy = fy or cy
    s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    return f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}" fx="{fx}" fy="{fy}">{s}</radialGradient>'


def linear(gid, stops, x1="0", y1="0", x2="0", y2="1"):
    s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in stops)
    return f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def shaded_blob(prefix, d, tips, cx, cy, base, light, shadow, rim=None, strand_col=None, seed=1,
                light_pos=(-0.35, -0.45), shadow_pos=(0.25, 0.55), rx=200, ry=180):
    """A fur blob with gradient fill, clipped soft light/shadow, strands, outline."""
    defs = (f'<clipPath id="{prefix}c"><path d="{d}"/></clipPath>'
            + radial(f"{prefix}g", [(0, light, 1), (0.55, base, 1), (1, shadow, 1)], cx="38%", cy="30%", r="80%")
            + blur_filter(f"{prefix}b", 22))
    body = f'<path d="{d}" fill="url(#{prefix}g)"/>'
    body += f'<g clip-path="url(#{prefix}c)">'
    body += (f'<ellipse cx="{f(cx + shadow_pos[0] * rx)}" cy="{f(cy + shadow_pos[1] * ry)}" rx="{f(rx * 0.9)}" '
             f'ry="{f(ry * 0.55)}" fill="{shadow}" opacity="0.55" filter="url(#{prefix}b)"/>')
    body += (f'<ellipse cx="{f(cx + light_pos[0] * rx)}" cy="{f(cy + light_pos[1] * ry)}" rx="{f(rx * 0.5)}" '
             f'ry="{f(ry * 0.35)}" fill="{light}" opacity="0.65" filter="url(#{prefix}b)"/>')
    body += strands(tips, cx, cy, strand_col or shadow, 3.5, 0.55, seed)
    if rim:
        defs += linear(f"{prefix}r", [(0, rim, 0), (0.55, rim, 0), (1, rim, 0.95)], x1="0.2", y1="0", x2="0.8", y2="1")
        body += f'<path d="{d}" fill="none" stroke="url(#{prefix}r)" stroke-width="16"/>'
    body += "</g>"
    body += f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{OUTLINE}" stroke-linejoin="round"/>'
    return defs, body


# ------------------------------------------------------------------ werecat layers

def head_shape():
    """One silhouette shared by the cute and scary heads, so the morph is a
    color shift with no double outlines."""
    def L(a):
        side = abs(math.cos(a))
        below = max(0.0, math.sin(a))
        return 12 + 26 * side * (0.55 + below) + 8 * below
    return fluffy(HC[0], HC[1], 212, 182, 24, L, seed=3, droop=0.3, bulge=0.28, sharp=0.32)


def head(scary):
    cx, cy = HC
    d, tips = head_shape()
    if scary:
        return shaded_blob("hs", d, tips, cx, cy, SFUR, SFUR_LIGHT, SFUR_SHADOW, rim=EMBER,
                           strand_col="#0B060B", seed=12, rx=212, ry=182)
    return shaded_blob("hc", d, tips, cx, cy, FUR, FUR_LIGHT, FUR_SHADOW, strand_col=FUR_SHADOW,
                       seed=4, rx=212, ry=182)


def ears(scary):
    defs, body = "", ""
    if scary:
        outer = [(262, 300), (232, 190), (214, 118), (205, 40), (252, 92), (246, 120), (290, 150), (350, 210), (372, 246)]
        inner = [(275, 272), (252, 190), (238, 120), (240, 96), (266, 126), (300, 162), (338, 220)]
        defs += linear("es_i", [(0, "#5A0C16", 1), (0.6, "#26060C", 1), (1, "#0E0306", 1)], x1="0.5", y1="1", x2="0.3", y2="0")
        defs += linear("es_o", [(0, SFUR_LIGHT, 1), (1, SFUR_SHADOW, 1)], x1="0", y1="0", x2="1", y2="1")
        fill_o, fill_i = "url(#es_o)", "url(#es_i)"
    else:
        outer = [(262, 300), (236, 210), (222, 150), (226, 96), (280, 128), (330, 176), (370, 240)]
        inner = [(276, 274), (254, 205), (244, 158), (246, 128), (284, 156), (318, 194), (342, 236)]
        defs += linear("ec_i", [(0, PINK, 1), (1, PINK_DEEP, 1)], x1="0.5", y1="1", x2="0.3", y2="0")
        defs += linear("ec_o", [(0, FUR_LIGHT, 1), (1, FUR_SHADOW, 1)], x1="0", y1="0", x2="1", y2="1")
        fill_o, fill_i = "url(#ec_o)", "url(#ec_i)"

    def poly(pts):
        d = f"M {pts[0][0]} {pts[0][1]} "
        for i in range(1, len(pts) - 1, 2):
            d += f"Q {pts[i][0]} {pts[i][1]} {pts[i + 1][0]} {pts[i + 1][1]} "
        if len(pts) % 2 == 0:
            d += f"L {pts[-1][0]} {pts[-1][1]} "
        return d + "Z"

    for side in (0, 1):
        o = outer if side == 0 else mirror_x(outer)
        i = inner if side == 0 else mirror_x(inner)
        body += f'<path d="{poly(o)}" fill="{fill_o}" stroke="{INK}" stroke-width="{OUTLINE}" stroke-linejoin="round"/>'
        body += f'<path d="{poly(i)}" fill="{fill_i}" stroke="{INK}" stroke-width="4" stroke-linejoin="round" opacity="0.95"/>'
        # ear-floof strokes
        tuft_col = CREAM if not scary else "#6A4A60"
        bx = 300 if side == 0 else 500
        for k, (dx, h) in enumerate([(-16, 58), (0, 76), (16, 52)]):
            sx = bx + dx
            body += (f'<path d="M {sx} 262 Q {sx + (8 if side == 0 else -8)} {262 - h / 2} {sx - (4 if side == 0 else -4)} {262 - h}" '
                     f'fill="none" stroke="{tuft_col}" stroke-width="5" stroke-linecap="round"/>')
    return defs, body


def horns():
    left = "M 352 236 C 344 186, 326 140, 300 82 C 296 74, 306 70, 312 76 C 350 118, 378 168, 396 226 Z"
    defs = linear("hn", [(0, "#4A3436", 1), (0.6, "#1E1214", 1), (1, "#0A0507", 1)], x1="0", y1="1", x2="0", y2="0")
    defs += linear("hnr", [(0, EMBER, 0), (1, EMBER, 0.9)], x1="0", y1="1", x2="1", y2="0")
    body = ""
    for side in (0, 1):
        tf = "" if side == 0 else f' transform="translate({W} 0) scale(-1 1)"'
        body += f'<g{tf}>'
        body += f'<path d="{left}" fill="url(#hn)" stroke="{INK}" stroke-width="{OUTLINE}" stroke-linejoin="round"/>'
        for k in range(5):
            y = 210 - k * 26
            x0 = 352 - k * 9
            body += f'<path d="M {x0 - 2} {y} Q {x0 + 18} {y - 10} {x0 + 36 - k * 3} {y - 4}" fill="none" stroke="#0A0507" stroke-width="3.5" stroke-linecap="round" opacity="0.8"/>'
        body += '<path d="M 314 90 C 342 124, 368 168, 386 222" fill="none" stroke="url(#hnr)" stroke-width="6" stroke-linecap="round"/>'
        body += "</g>"
    return defs, body


def spikes():
    cx, cy = HC
    rnd = random.Random(21)
    n = 26
    pts = []
    for i in range(n):
        a = -math.pi / 2 + i * 2 * math.pi / n
        r_out = rnd.uniform(300, 360) * (1.0 if math.sin(a) < 0.6 else 0.85)
        a_in = a + math.pi / n
        pts.append((cx + math.cos(a) * r_out * 1.08, cy + math.sin(a) * r_out * 0.95))
        pts.append((cx + math.cos(a_in) * 215, cy + math.sin(a_in) * 190))
    d = f"M {f(pts[0][0])} {f(pts[0][1])} "
    for i in range(1, len(pts) + 1):
        p = pts[i % len(pts)]
        q = pts[i - 1]
        mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
        # slight inward curve
        mx += (cx - mx) * 0.06
        my += (cy - my) * 0.06
        d += f"Q {f(mx)} {f(my)} {f(p[0])} {f(p[1])} "
    d += "Z"
    defs = radial("sp", [(0, "#3A1020", 1), (0.6, "#1C0810", 1), (1, "#070205", 1)], r="60%")
    defs += blur_filter("spb", 26)
    body = f'<path d="{d}" fill="{EMBER}" opacity="0.45" filter="url(#spb)"/>'
    body += f'<path d="{d}" fill="url(#sp)" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
    return defs, body


def muzzle(scary):
    shapes = [("circle", 356, 470, 60), ("circle", 444, 470, 60), ("ellipse", 400, 506, 52, 36)]
    if scary:
        defs = radial("mz", [(0, "#5C4656", 1), (1, "#2A1C28", 1)], cy="35%")
    else:
        defs = radial("mz", [(0, "#FFFFFF", 1), (0.5, CREAM, 1), (1, CREAM_SHADOW, 1)], cy="30%")

    def el(s, fill, stroke, sw):
        if s[0] == "circle":
            return f'<circle cx="{s[1]}" cy="{s[2]}" r="{s[3]}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
        return f'<ellipse cx="{s[1]}" cy="{s[2]}" rx="{s[3]}" ry="{s[4]}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
    body = "".join(el(s, INK, INK, OUTLINE * 2) for s in shapes)
    body += "".join(el(s, "url(#mz)", "none", 0) for s in shapes)
    # whisker dots
    dot = "#C79B78" if not scary else "#170D15"
    for x, y in [(342, 470), (330, 488), (352, 492), (458, 470), (470, 488), (448, 492)]:
        body += f'<circle cx="{x}" cy="{y}" r="3.2" fill="{dot}"/>'
    if scary:
        # snarl wrinkles on the bridge
        for dx in (-1, 1):
            for k in range(3):
                x = 400 + dx * (18 + k * 9)
                body += f'<path d="M {x} {404 - k * 4} q {dx * 10} -10 {dx * 22} -6" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>'
    # dog nose
    defs += radial("ns", [(0, "#5A3A4C", 1), (1, "#160A12", 1)], cy="25%", r="70%")
    nose = "M 360 424 C 358 402, 442 402, 440 424 C 438 444, 416 456, 400 462 C 384 456, 362 444, 360 424 Z"
    body += f'<path d="{nose}" fill="url(#ns)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    body += '<ellipse cx="386" cy="416" rx="14" ry="6.5" fill="#FFFFFF" opacity="0.75" transform="rotate(-10 386 416)"/>'
    body += '<circle cx="414" cy="415" r="3.5" fill="#FFFFFF" opacity="0.6"/>'
    body += f'<path d="M 400 462 L 400 478" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
    return defs, body


def mouth_cute():
    defs = linear("tg", [(0, "#FF9DBA", 1), (1, "#E0577F", 1)])
    body = (f'<path d="M 400 478 C 395 494, 370 497, 357 484" fill="none" stroke="{INK}" stroke-width="5.5" stroke-linecap="round"/>'
            f'<path d="M 400 478 C 405 494, 430 497, 443 484" fill="none" stroke="{INK}" stroke-width="5.5" stroke-linecap="round"/>')
    body += f'<path d="M 404 487 C 402 516, 434 520, 434 489 Z" fill="url(#tg)" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
    body += f'<path d="M 419 492 L 419 506" stroke="#C2406A" stroke-width="3" stroke-linecap="round"/>'
    body += '<ellipse cx="412" cy="496" rx="4" ry="2.5" fill="#FFFFFF" opacity="0.6"/>'
    return defs, body


def mouth_scary():
    defs = radial("mw", [(0, "#6A0E20", 1), (0.6, "#2A0410", 1), (1, "#0C0206", 1)], cy="30%")
    defs += linear("th", [(0, "#FFFDF4", 1), (1, "#D6CBAE", 1)])
    maw = "M 326 484 C 344 466, 456 466, 474 484 C 466 548, 432 578, 400 580 C 368 578, 334 548, 326 484 Z"
    body = f'<path d="{maw}" fill="url(#mw)" stroke="{INK}" stroke-width="{OUTLINE}" stroke-linejoin="round"/>'
    body += '<ellipse cx="400" cy="560" rx="44" ry="16" fill="#7A1A2C"/>'
    body += '<path d="M 400 548 L 400 568" stroke="#4A0A18" stroke-width="3" stroke-linecap="round"/>'

    def tooth(x0, x1, tip_x, tip_y, base_y, curve=0):
        return (f'<path d="M {x0} {base_y} Q {(x0 + tip_x) / 2 - curve} {(base_y + tip_y) / 2} {tip_x} {tip_y} '
                f'Q {(x1 + tip_x) / 2 - curve} {(base_y + tip_y) / 2} {x1} {base_y} Z" fill="url(#th)" '
                f'stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>')
    for x in (378, 390, 410, 422):
        body += tooth(x - 5, x + 5, x, 494, 478)
    body += tooth(346, 366, 360, 540, 480, curve=-4)
    body += tooth(434, 454, 440, 540, 480, curve=4)
    body += tooth(362, 378, 372, 540, 572, curve=-2)
    body += tooth(422, 438, 428, 540, 572, curve=2)
    return defs, body


def drool():
    defs = blur_filter("dr", 6)
    d = "M 446 520 C 444 538, 448 552, 446 566 C 456 572, 456 590, 446 592 C 436 590, 436 572, 446 566 C 444 552, 440 538, 442 520 Z"
    body = f'<path d="{d}" fill="#6CFF3A" opacity="0.8" filter="url(#dr)"/>'
    body += f'<path d="{d}" fill="{ICHOR}" stroke="#1E4A12" stroke-width="2.5"/>'
    body += '<ellipse cx="443" cy="576" rx="2.5" ry="4" fill="#FFFFFF" opacity="0.8"/>'
    return defs, body


def eyes_cute(closed=False):
    defs = radial("ir", [(0, "#9A7BD0", 1), (0.55, "#53357A", 1), (1, "#1E0F2C", 1)], cy="62%", r="60%")
    body = ""
    for cx in (318, 482):
        cy = 368
        if closed:
            body += f'<path d="M {cx - 46} {cy - 4} Q {cx} {cy + 26} {cx + 46} {cy - 4}" fill="none" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>'
            continue
        body += f'<ellipse cx="{cx}" cy="{cy}" rx="50" ry="56" fill="url(#ir)" stroke="{INK}" stroke-width="{OUTLINE}"/>'
        body += f'<ellipse cx="{cx + 2}" cy="{cy + 4}" rx="27" ry="31" fill="#120818"/>'
        body += f'<path d="M {cx - 34} {cy + 30} Q {cx} {cy + 50} {cx + 34} {cy + 30}" fill="none" stroke="#C8B0F0" stroke-width="4" stroke-linecap="round" opacity="0.55"/>'
        body += f'<ellipse cx="{cx - 16}" cy="{cy - 20}" rx="16" ry="14" fill="#FFFFFF"/>'
        body += f'<circle cx="{cx + 18}" cy="{cy + 16}" r="7" fill="#FFFFFF"/>'
        body += f'<circle cx="{cx + 24}" cy="{cy - 8}" r="3.2" fill="#FFFFFF" opacity="0.85"/>'
        flick = -1 if cx < 400 else 1
        ox = cx + flick * 46
        body += f'<path d="M {ox} {cy - 26} q {flick * 14} -6 {flick * 22} -18" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
    # blush
    defs += blur_filter("bl", 8)
    for cx in (276, 524):
        body += f'<ellipse cx="{cx}" cy="440" rx="30" ry="15" fill="#FF7FA6" opacity="0.55" filter="url(#bl)"/>'
    return defs, body


def eyes_scary():
    left = "M 258 336 C 290 330, 344 352, 374 386 C 346 402, 284 398, 258 336 Z"
    defs = (radial("sc", [(0, "#4A0C16", 1), (1, "#140306", 1)])
            + radial("si", [(0, "#FFF2A0", 1), (0.35, EMBER_HOT, 1), (0.7, EMBER, 1), (1, "#A0101A", 1)])
            + f'<clipPath id="ecl"><path d="{left}"/></clipPath>'
            + f'<clipPath id="ecr"><path d="{left}" transform="translate({W} 0) scale(-1 1)"/></clipPath>')
    body = ""
    for side in (0, 1):
        tf = "" if side == 0 else f' transform="translate({W} 0) scale(-1 1)"'
        body += f'<g{tf}><path d="{left}" fill="url(#sc)"/></g>'
        cx = 322 if side == 0 else W - 322
        clip = "ecl" if side == 0 else "ecr"
        body += f'<g clip-path="url(#{clip})">'
        body += f'<circle cx="{cx}" cy="370" r="31" fill="url(#si)"/>'
        body += f'<ellipse cx="{cx}" cy="370" rx="5.5" ry="27" fill="#0A0204"/>'
        body += f'<circle cx="{cx - 10}" cy="356" r="4" fill="#FFFFFF" opacity="0.9"/>'
        body += "</g>"
        body += f'<g{tf}><path d="{left}" fill="none" stroke="{INK}" stroke-width="{OUTLINE}" stroke-linejoin="round"/></g>'
    # brows
    brow = "M 244 316 C 290 308, 344 330, 386 364 L 378 376 C 338 348, 292 332, 248 332 Z"
    for side in (0, 1):
        tf = "" if side == 0 else f' transform="translate({W} 0) scale(-1 1)"'
        body += f'<g{tf}><path d="{brow}" fill="{INK}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/></g>'
    return defs, body


def eye_glow():
    defs = blur_filter("eg", 26)
    body = ""
    for cx in (322, 478):
        body += f'<ellipse cx="{cx}" cy="368" rx="78" ry="56" fill="#FF3A1A" opacity="0.9" filter="url(#eg)"/>'
    return defs, body


def whiskers():
    body = ""
    for side in (-1, 1):
        for k, (ex, ey) in enumerate([(200, 446), (194, 480), (210, 514)]):
            sx = 400 + side * 64
            sy = 474 + k * 12
            ex = 400 + side * (400 - ex)
            mx = (sx + ex) / 2
            my = (sy + ey) / 2 - 10
            d = f"M {sx} {sy} Q {f(mx)} {f(my)} {ex} {ey}"
            body += f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="6.5" stroke-linecap="round"/>'
            body += f'<path d="{d}" fill="none" stroke="#FFF7EC" stroke-width="3" stroke-linecap="round"/>'
    return "", body


def body_blob(scary):
    cx, cy = 400, 650
    if scary:
        d, tips = fluffy(cx, cy, 196, 120, 20, lambda a: 24, seed=33, droop=0.3, bulge=0.28, sharp=0.32)
        defs, body = shaded_blob("bs", d, tips, cx, cy, SFUR, SFUR_LIGHT, SFUR_SHADOW, rim=EMBER,
                                 strand_col="#0B060B", seed=32, rx=196, ry=120)
        return defs, body
    d, tips = fluffy(cx, cy, 196, 120, 20, lambda a: 24, seed=33, droop=0.3, bulge=0.28, sharp=0.32)
    defs, body = shaded_blob("bc", d, tips, cx, cy, FUR, FUR_LIGHT, FUR_SHADOW, seed=34, rx=196, ry=120)
    # chest floof
    d2, tips2 = fluffy(400, 600, 92, 70, 14, lambda a: 20 + 12 * max(0, math.sin(a)), seed=35)
    d3, b3 = shaded_blob("ch", d2, tips2, 400, 600, CREAM, "#FFFFFF", CREAM_SHADOW, seed=36, rx=92, ry=70)
    return defs + d3, body + b3


def paws():
    defs = radial("pw", [(0, FUR_LIGHT, 1), (0.6, FUR, 1), (1, FUR_SHADOW, 1)], cy="30%")
    body = ""
    for cx in (316, 484):
        cy = 706
        parts = [("e", cx, cy, 54, 38), ("c", cx - 30, cy - 20, 20), ("c", cx, cy - 30, 21), ("c", cx + 30, cy - 20, 20)]

        def el(p, fill, stroke, sw):
            if p[0] == "c":
                return f'<circle cx="{p[1]}" cy="{p[2]}" r="{p[3]}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
            return f'<ellipse cx="{p[1]}" cy="{p[2]}" rx="{p[3]}" ry="{p[4]}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
        body += "".join(el(p, INK, INK, OUTLINE * 2) for p in parts)
        body += "".join(el(p, "url(#pw)", "none", 0) for p in parts)
        for dx in (-15, 15):
            body += f'<path d="M {cx + dx} {cy - 34} Q {cx + dx * 1.1} {cy - 22} {cx + dx} {cy - 12}" fill="none" stroke="{FUR_SHADOW}" stroke-width="4" stroke-linecap="round"/>'
        body += f'<ellipse cx="{cx - 14}" cy="{cy - 34}" rx="9" ry="5" fill="#FFFFFF" opacity="0.5"/>'
    return defs, body


def paws_scary():
    defs = radial("pws", [(0, SFUR_LIGHT, 1), (0.6, SFUR, 1), (1, SFUR_SHADOW, 1)], cy="30%")
    defs += linear("cl", [(0, "#FFFFFF", 1), (1, BONE, 1)])
    body = ""
    for cx in (316, 484):
        cy = 706
        # claws hook over the frame edge
        for dx in (-30, 0, 30):
            x = cx + dx
            body += (f'<path d="M {x - 8} {cy - 6} C {x - 6} {cy + 18}, {x + 2} {cy + 34}, {x + 10} {cy + 40} '
                     f'C {x + 6} {cy + 26}, {x + 8} {cy + 10}, {x + 8} {cy - 6} Z" fill="url(#cl)" stroke="{INK}" '
                     f'stroke-width="3.5" stroke-linejoin="round"/>')
        parts = [("e", cx, cy, 52, 34), ("c", cx - 30, cy - 18, 19), ("c", cx, cy - 27, 20), ("c", cx + 30, cy - 18, 19)]

        def el(p, fill, stroke, sw):
            if p[0] == "c":
                return f'<circle cx="{p[1]}" cy="{p[2]}" r="{p[3]}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
            return f'<ellipse cx="{p[1]}" cy="{p[2]}" rx="{p[3]}" ry="{p[4]}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
        body += "".join(el(p, INK, INK, OUTLINE * 2) for p in parts)
        body += "".join(el(p, "url(#pws)", "none", 0) for p in parts)
        body += f'<path d="M {cx - 40} {cy + 6} Q {cx} {cy + 22} {cx + 40} {cy + 6}" fill="none" stroke="{EMBER}" stroke-width="3" opacity="0.6"/>'
    return defs, body


def arm_segment(name):
    w, h, px, py, dx, dy = ARM_PIVOTS[name]
    defs = linear("ag", [(0, MANTIS_LIGHT, 1), (0.45, MANTIS, 1), (1, MANTIS_SHADOW, 1)])
    defs += linear("sg", [(0, "#FFFFFF", 1), (1, BONE, 1)])
    body = ""
    if name == "arm_coxa":
        d = f"M {px} {py - 22} C {px + 40} {py - 28}, {dx - 10} {dy - 18}, {dx + 4} {dy - 6} C {dx + 10} {dy + 6}, {dx - 10} {dy + 16}, {dx - 30} {dy + 18} C {px + 30} {py + 22}, {px - 12} {py + 18}, {px} {py - 22} Z"
        spines = []
    elif name == "arm_femur":
        d = (f"M {px - 8} {py - 18} C {px + 60} {py - 40}, {dx - 60} {dy - 30}, {dx + 10} {dy - 8} "
             f"C {dx + 16} {dy + 4}, {dx + 4} {dy + 16}, {dx - 20} {dy + 18} "
             f"C {dx - 90} {dy + 24}, {px + 60} {py + 30}, {px - 4} {py + 20} "
             f"C {px - 18} {py + 14}, {px - 18} {py - 10}, {px - 8} {py - 18} Z")
        spines = [(px + 50 + i * 32, py + 26 - abs(i - 3) * 1.5, 26 if i % 2 == 0 else 16) for i in range(7)]
    else:
        d = (f"M {px - 6} {py - 14} C {px + 70} {py - 24}, {dx - 50} {dy - 18}, {dx} {dy - 6} "
             f"C {dx + 20} {dy + 2}, {dx + 26} {dy + 30}, {dx + 8} {dy + 56} "
             f"C {dx + 12} {dy + 30}, {dx} {dy + 16}, {dx - 14} {dy + 14} "
             f"C {dx - 70} {dy + 16}, {px + 40} {py + 18}, {px - 4} {py + 14} "
             f"C {px - 16} {py + 8}, {px - 16} {py - 8}, {px - 6} {py - 14} Z")
        spines = [(px + 40 + i * 30, py + 16, 16 if i % 2 == 0 else 10) for i in range(6)]
    for sx, sy, L in spines:
        body += (f'<path d="M {sx - 7} {sy - 4} L {sx + L * 0.35} {sy + L} L {sx + 7} {sy - 4} Z" fill="url(#sg)" '
                 f'stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>')
    body += f'<path d="{d}" fill="url(#ag)" stroke="{INK}" stroke-width="{OUTLINE - 1}" stroke-linejoin="round"/>'
    # glossy highlight
    body += (f'<path d="M {px + 14} {py - 8} C {px + 80} {py - 18}, {dx - 60} {dy - 14}, {dx - 20} {dy - 8}" fill="none" '
             f'stroke="#E6FFC8" stroke-width="5" stroke-linecap="round" opacity="0.55"/>')
    # segment bands
    for t in (0.33, 0.66):
        x = px + (dx - px) * t
        body += f'<path d="M {x} {py - 14} Q {x + 6} {py} {x} {py + 14}" fill="none" stroke="{MANTIS_SHADOW}" stroke-width="3" opacity="0.7"/>'
    return defs, body, w, h


# ------------------------------------------------------------------ UI bits

def heart(name, fill1, fill2, size=64):
    d = "M 32 56 C 10 42, 4 28, 8 18 C 12 8, 26 6, 32 16 C 38 6, 52 8, 56 18 C 60 28, 54 42, 32 56 Z"
    defs = radial("hg", [(0, fill1, 1), (1, fill2, 1)], cx="40%", cy="30%", r="70%")
    body = f'<path d="{d}" fill="url(#hg)" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
    body += '<ellipse cx="22" cy="20" rx="6" ry="4" fill="#FFFFFF" opacity="0.7" transform="rotate(-30 22 20)"/>'
    render(name, body, defs, size, size)


def bat_icon(name, size=96):
    d = ("M 48 58 C 40 50, 30 44, 8 40 C 16 46, 18 54, 14 62 C 22 58, 30 60, 34 66 C 38 60, 44 60, 48 64 "
         "C 52 60, 58 60, 62 66 C 66 60, 74 58, 82 62 C 78 54, 80 46, 88 40 C 66 44, 56 50, 48 58 Z")
    defs = linear("bg", [(0, "#3A2034", 1), (1, "#0C050B", 1)])
    defs += blur_filter("bgl", 5)
    body = f'<path d="{d}" fill="#FF3A1A" opacity="0.55" filter="url(#bgl)"/>'
    body += f'<path d="{d}" fill="url(#bg)" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    body += '<path d="M 40 50 L 42 40 L 46 48 Z M 56 50 L 54 40 L 50 48 Z" fill="#1A0C18" stroke="#1A0C18" stroke-width="2" stroke-linejoin="round"/>'
    body += '<circle cx="44" cy="54" r="2.6" fill="#FFB03A"/><circle cx="52" cy="54" r="2.6" fill="#FFB03A"/>'
    render(name, body, defs, size, size)


def puff_icon(name, size=96):
    d, tips = fluffy(48, 50, 26, 24, 14, lambda a: 8, seed=41, droop=0.2)
    defs = radial("pf", [(0, "#FFFFFF", 1), (0.5, "#FFD3E6", 1), (1, "#F39DC0", 1)], cx="40%", cy="35%", r="70%")
    body = f'<path d="{d}" fill="url(#pf)" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
    body += '<ellipse cx="40" cy="48" rx="4" ry="5.5" fill="#241226"/><ellipse cx="56" cy="48" rx="4" ry="5.5" fill="#241226"/>'
    body += '<circle cx="38.5" cy="46" r="1.6" fill="#FFFFFF"/><circle cx="54.5" cy="46" r="1.6" fill="#FFFFFF"/>'
    body += '<path d="M 44 56 Q 48 60 52 56" fill="none" stroke="#241226" stroke-width="2.5" stroke-linecap="round"/>'
    body += '<ellipse cx="34" cy="56" rx="4" ry="2.5" fill="#FF7FA6" opacity="0.7"/><ellipse cx="62" cy="56" rx="4" ry="2.5" fill="#FF7FA6" opacity="0.7"/>'
    render(name, body, defs, size, size)


def sparkle(name, color, size=48):
    defs = blur_filter("sk", 3)
    d = "M 24 4 C 26 18, 30 22, 44 24 C 30 26, 26 30, 24 44 C 22 30, 18 26, 4 24 C 18 22, 22 18, 24 4 Z"
    body = f'<path d="{d}" fill="{color}" opacity="0.8" filter="url(#sk)"/><path d="{d}" fill="#FFFFFF"/>'
    render(name, body, defs, size, size)


def soft_glow(name, size=128):
    stops = "".join(f'<stop offset="{o:.2f}" stop-color="#FFFFFF" stop-opacity="{math.exp(-((o * 2.6) ** 2)):.3f}"/>'
                    for o in [i / 10 for i in range(11)])
    defs = f'<radialGradient id="sg">{stops}</radialGradient>'
    render(name, f'<circle cx="{size / 2}" cy="{size / 2}" r="{size / 2}" fill="url(#sg)"/>', defs, size, size)


def ember(name, size=32):
    defs = radial("em", [(0, "#FFF2B0", 1), (0.35, EMBER_HOT, 1), (0.7, EMBER, 0.6), (1, EMBER, 0)])
    body = '<circle cx="16" cy="16" r="16" fill="url(#em)"/>'
    render(name, body, defs, size, size)


# ------------------------------------------------------------------ main

LAYERS = {
    "wc_spikes": spikes,
    "wc_body_cute": lambda: body_blob(False),
    "wc_body_scary": lambda: body_blob(True),
    "wc_ears_cute": lambda: ears(False),
    "wc_ears_scary": lambda: ears(True),
    "wc_horns": horns,
    "wc_head_cute": lambda: head(False),
    "wc_head_scary": lambda: head(True),
    "wc_muzzle_cute": lambda: muzzle(False),
    "wc_muzzle_scary": lambda: muzzle(True),
    "wc_whiskers": whiskers,
    "wc_eyes_cute": lambda: eyes_cute(False),
    "wc_eyes_blink": lambda: eyes_cute(True),
    "wc_eyes_scary": eyes_scary,
    "wc_eye_glow": eye_glow,
    "wc_mouth_cute": mouth_cute,
    "wc_mouth_scary": mouth_scary,
    "wc_drool": drool,
    "wc_paws": paws,
    "wc_paws_scary": paws_scary,
}

if __name__ == "__main__":
    for name, fn in LAYERS.items():
        defs, body = fn()
        render(name, body, defs)
    for name in ARM_PIVOTS:
        defs, body, w, h = arm_segment(name)
        render(name, body, defs, w, h)
    heart("ui_heart", "#FFB3CB", "#E3507E")
    heart("ui_heart_empty", "#4A3446", "#2A1A28")
    bat_icon("bouncer_bat")
    puff_icon("bouncer_puff")
    sparkle("fx_sparkle", "#FFB3E0")
    ember("fx_ember")
    soft_glow("fx_glow")
    print("ok", len(LAYERS) + len(ARM_PIVOTS) + 6, "sprites")
