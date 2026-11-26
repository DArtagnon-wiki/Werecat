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



# ------------------------------------------------------------------ entities (mechanics)

def _eyes(cx, cy, dx, r, col="#241226", hl=True, glow=None):
    out = ""
    for sx in (-1, 1):
        x = cx + sx * dx
        if glow:
            out += f'<circle cx="{x}" cy="{cy}" r="{r * 2.2}" fill="{glow}" opacity="0.55" filter="url(#eb)"/>'
        out += f'<ellipse cx="{x}" cy="{cy}" rx="{r}" ry="{r * 1.2}" fill="{col}"/>'
        if hl:
            out += f'<circle cx="{x - r * 0.35}" cy="{cy - r * 0.45}" r="{r * 0.38}" fill="#FFFFFF"/>'
    return out


def bomb(name="ent_bomb", size=120):
    defs = radial("bm", [(0, "#5B4A8A", 1), (0.5, "#2C2050", 1), (1, "#120A24", 1)], cx="38%", cy="32%", r="70%")
    defs += blur_filter("eb", 3) + blur_filter("fz", 4)
    c = size / 2
    body = f'<circle cx="{c}" cy="{c + 8}" r="40" fill="url(#bm)" stroke="{INK}" stroke-width="5"/>'
    # star decal
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 14 if k % 2 == 0 else 6
        pts.append(f"{c + math.cos(a) * r:.1f},{c + 12 + math.sin(a) * r:.1f}")
    body += f'<polygon points="{" ".join(pts)}" fill="#FFB3CB" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>'
    body += f'<ellipse cx="{c - 14}" cy="{c - 8}" rx="11" ry="7" fill="#FFFFFF" opacity="0.45" transform="rotate(-30 {c - 14} {c - 8})"/>'
    # cap + fuse
    body += f'<rect x="{c - 12}" y="{c - 40}" width="24" height="14" rx="4" fill="#3A2E5A" stroke="{INK}" stroke-width="4"/>'
    body += f'<path d="M {c} {c - 40} C {c + 4} {c - 52}, {c + 18} {c - 50}, {c + 22} {c - 56}" fill="none" stroke="#C9A06A" stroke-width="5" stroke-linecap="round"/>'
    body += f'<circle cx="{c + 23}" cy="{c - 57}" r="9" fill="#FFB03A" opacity="0.9" filter="url(#fz)"/>'
    body += f'<circle cx="{c + 23}" cy="{c - 57}" r="4" fill="#FFF6C0"/>'
    render(name, body, defs, size, size)


def carver(prefix, scary):
    """Head + body segment sprites for a carving worm."""
    if scary:
        g = [(0, "#5A3E58", 1), (0.6, "#2A1A2C", 1), (1, "#120A14", 1)]
        belly, eye, glow = "#FF5A2E", "#FFC04A", "#FF3A1A"
    else:
        g = [(0, "#FFFFFF", 1), (0.5, "#C7F2E4", 1), (1, "#7FD3C0", 1)]
        belly, eye, glow = "#FF9DBA", INK, None
    defs = radial("cv", g, cx="40%", cy="30%", r="70%") + blur_filter("eb", 4)
    # segment
    seg = ""
    if scary:
        for y0, sgn in ((9, 1), (63, -1)):
            seg += f'<path d="M 28 {y0 + sgn * 4} L 36 {y0 - sgn * 6} L 44 {y0 + sgn * 4} Z" fill="#1A0E1A" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    seg += f'<ellipse cx="36" cy="36" rx="24" ry="27" fill="url(#cv)" stroke="{INK}" stroke-width="5"/>'
    # segment ridges (vertical arcs) + spots
    for x in (24, 48):
        seg += f'<path d="M {x} 14 Q {x + (6 if x < 36 else -6)} 36 {x} 58" fill="none" stroke="{INK}" stroke-width="2.5" opacity="0.45"/>'
    if scary:
        for cx, cy in ((36, 26), (31, 44), (41, 46)):
            seg += f'<circle cx="{cx}" cy="{cy}" r="3.2" fill="{belly}" opacity="0.9"/>'
    else:
        seg += f'<circle cx="31" cy="25" r="5" fill="#FFFFFF" opacity="0.75"/><circle cx="40" cy="45" r="4" fill="{belly}" opacity="0.6"/>'
    render(prefix + "_seg", seg, defs, 72, 72)
    # head (faces +x)
    head = f'<ellipse cx="50" cy="48" rx="38" ry="34" fill="url(#cv)" stroke="{INK}" stroke-width="5"/>'
    if scary:
        head += f'<path d="M 70 58 Q 82 62 88 56 L 84 66 L 78 62 L 74 68 L 70 62 Z" fill="#FFF6E0" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
        head += _eyes(60, 38, 13, 6, col=eye, hl=False, glow=glow)
        head += f'<path d="M 44 28 L 76 34" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
        for k, (x, y) in enumerate([(28, 18), (40, 12), (52, 12)]):
            head += f'<path d="M {x - 6} {y + 10} L {x} {y - 6} L {x + 6} {y + 10} Z" fill="#1A0E1A" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    else:
        head += _eyes(62, 42, 12, 6)
        head += f'<path d="M 64 60 Q 72 66 80 60" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>'
        head += '<ellipse cx="50" cy="56" rx="6" ry="3.5" fill="#FF7FA6" opacity="0.7"/><ellipse cx="82" cy="54" rx="5" ry="3" fill="#FF7FA6" opacity="0.7"/>'
        head += f'<path d="M 46 18 Q 40 4 30 8" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/><circle cx="29" cy="8" r="6" fill="#FFB3CB" stroke="{INK}" stroke-width="3"/>'
    render(prefix + "_head", head, defs, 100, 96)


def wisp(name="ent_wisp", size=120):
    c = size / 2
    d = (f"M {c} {c + 34} C {c - 30} {c + 34}, {c - 34} {c + 6}, {c - 22} {c - 10} C {c - 14} {c - 22}, {c - 18} {c - 34}, {c - 6} {c - 48} "
         f"C {c - 4} {c - 34}, {c + 4} {c - 30}, {c + 8} {c - 40} C {c + 14} {c - 26}, {c + 30} {c - 18}, {c + 28} {c + 4} "
         f"C {c + 30} {c + 26}, {c + 18} {c + 34}, {c} {c + 34} Z")
    defs = radial("wp", [(0, "#F2FFFF", 1), (0.4, "#8FF0FF", 0.95), (1, "#7A4BD8", 0.85)], cy="65%", r="70%")
    defs += blur_filter("wb", 8) + blur_filter("eb", 3)
    body = f'<path d="{d}" fill="#9AF6FF" opacity="0.7" filter="url(#wb)"/>'
    body += f'<path d="{d}" fill="url(#wp)" stroke="#2A1450" stroke-width="4" stroke-linejoin="round"/>'
    body += f'<ellipse cx="{c - 9}" cy="{c + 8}" rx="6" ry="9" fill="#1A0838"/><ellipse cx="{c + 9}" cy="{c + 8}" rx="6" ry="9" fill="#1A0838"/>'
    body += f'<ellipse cx="{c}" cy="{c + 24}" rx="5" ry="4" fill="#1A0838"/>'
    render(name, body, defs, size, size)


def hunter_bat(name="ent_hunter", size=130):
    d = ("M 65 78 C 54 66, 40 58, 8 52 C 18 60, 20 70, 15 82 C 26 76, 38 79, 42 88 C 48 80, 57 80, 65 86 "
         "C 73 80, 82 80, 88 88 C 92 79, 104 76, 115 82 C 110 70, 112 60, 122 52 C 90 58, 76 66, 65 78 Z")
    defs = linear("hb", [(0, "#6A1A2A", 1), (1, "#1A050A", 1)]) + blur_filter("hgl", 7) + blur_filter("eb", 3)
    body = f'<path d="{d}" fill="#FF2A10" opacity="0.6" filter="url(#hgl)"/>'
    body += f'<path d="{d}" fill="url(#hb)" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
    # wing ribs
    for x1, y1 in [(20, 60), (34, 62), (96, 62), (110, 60)]:
        body += f'<path d="M 65 76 Q {(65 + x1) / 2} {y1 - 4} {x1} {y1}" fill="none" stroke="#0A0204" stroke-width="2" opacity="0.7"/>'
    # horns + ears
    body += f'<path d="M 54 66 C 48 52, 46 42, 50 34 C 54 44, 58 52, 60 64 Z M 76 66 C 82 52, 84 42, 80 34 C 76 44, 72 52, 70 64 Z" fill="#120408" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>'
    body += _eyes(65, 74, 7, 3.6, col="#FFB03A", hl=False, glow="#FF3A1A")
    body += '<path d="M 60 82 L 62 87 L 64 82 M 66 82 L 68 87 L 70 82" fill="#FFF6E0" stroke="#FFF6E0" stroke-width="1.5"/>'
    render(name, body, defs, size, size)


def huggy_puff(name="ent_huggy", size=110):
    d, tips = fluffy(55, 58, 30, 28, 16, lambda a: 9, seed=44, droop=0.2)
    defs = radial("hp", [(0, "#FFFFFF", 1), (0.5, "#FFC2DC", 1), (1, "#F07AAE", 1)], cx="40%", cy="35%", r="70%")
    defs += blur_filter("eb", 3)
    body = ""
    # little reaching arms
    for sx in (-1, 1):
        body += f'<path d="M {55 + sx * 26} 62 Q {55 + sx * 44} 50 {55 + sx * 48} 36" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>'
        body += f'<path d="M {55 + sx * 26} 62 Q {55 + sx * 44} 50 {55 + sx * 48} 36" fill="none" stroke="#FFC2DC" stroke-width="4.5" stroke-linecap="round"/>'
    body += f'<path d="{d}" fill="url(#hp)" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
    for sx in (-1, 1):
        x = 55 + sx * 10
        body += (f'<path d="M {x} 60 C {x - 9} 53, {x - 8} 45, {x - 3} 46 C {x - 1} 46, {x} 48, {x} 49 '
                 f'C {x} 48, {x + 1} 46, {x + 3} 46 C {x + 8} 45, {x + 9} 53, {x} 60 Z" fill="#E0204E" stroke="{INK}" stroke-width="1.8"/>')
    body += f'<path d="M 50 67 Q 55 72 60 67" fill="none" stroke="{INK}" stroke-width="2.5" stroke-linecap="round"/>'
    render(name, body, defs, size, size)


def nest(name, scary, size=130):
    c = size / 2
    defs = blur_filter("eb", 3) + blur_filter("ng", 8)
    if scary:
        defs += radial("ns1", [(0, "#4A2A3E", 1), (1, "#160A12", 1)], cy="35%")
        body = f'<ellipse cx="{c}" cy="{c + 6}" rx="44" ry="50" fill="#FF3A1A" opacity="0.35" filter="url(#ng)"/>'
        body += f'<path d="M {c} {c - 50} C {c + 40} {c - 44}, {c + 48} {c + 30}, {c} {c + 54} C {c - 48} {c + 30}, {c - 40} {c - 44}, {c} {c - 50} Z" fill="url(#ns1)" stroke="{INK}" stroke-width="5"/>'
        for k in range(5):
            y = c - 30 + k * 16
            body += f'<path d="M {c - 34 + abs(k - 2) * 4} {y} Q {c} {y + 8} {c + 34 - abs(k - 2) * 4} {y}" fill="none" stroke="#0A0408" stroke-width="3" opacity="0.8"/>'
        body += f'<ellipse cx="{c}" cy="{c + 8}" rx="18" ry="22" fill="#0A0206" stroke="{INK}" stroke-width="3"/>'
        body += _eyes(c, c + 8, 7, 3.5, col="#FFB03A", hl=False, glow="#FF3A1A")
        body += f'<path d="M {c} {c - 50} L {c} {c - 62}" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
    else:
        defs += linear("gb", [(0, "#C9F2FF", 1), (1, "#8FC8F0", 1)]) + linear("rb", [(0, "#FF9DBA", 1), (1, "#E0577F", 1)])
        body = f'<rect x="{c - 36}" y="{c - 14}" width="72" height="58" rx="8" fill="url(#gb)" stroke="{INK}" stroke-width="5"/>'
        body += f'<rect x="{c - 42}" y="{c - 30}" width="84" height="22" rx="7" fill="url(#gb)" stroke="{INK}" stroke-width="5"/>'
        body += f'<rect x="{c - 7}" y="{c - 30}" width="14" height="74" fill="url(#rb)" stroke="{INK}" stroke-width="3.5"/>'
        body += f'<path d="M {c} {c - 32} C {c - 30} {c - 64}, {c - 40} {c - 30}, {c} {c - 32} C {c + 40} {c - 30}, {c + 30} {c - 64}, {c} {c - 32} Z" fill="url(#rb)" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
        body += _eyes(c - 18, c + 16, 0, 0.1)  # (placeholder for symmetry)
        body += f'<circle cx="{c - 20}" cy="{c + 4}" r="5" fill="#FFFFFF" opacity="0.55"/>'
    render(name, body, defs, size, size)


def seed(name, scary, size=100):
    c = size / 2
    defs = blur_filter("sgl", 7)
    if scary:
        defs += radial("sd", [(0, "#5A2A3A", 1), (1, "#14060C", 1)], cy="35%")
        body = f'<circle cx="{c}" cy="{c}" r="30" fill="#FF3A1A" opacity="0.45" filter="url(#sgl)"/>'
        for k in range(8):
            a = k * math.pi / 4
            body += (f'<path d="M {c + math.cos(a - 0.25) * 22:.1f} {c + math.sin(a - 0.25) * 22:.1f} L {c + math.cos(a) * 44:.1f} {c + math.sin(a) * 44:.1f} '
                     f'L {c + math.cos(a + 0.25) * 22:.1f} {c + math.sin(a + 0.25) * 22:.1f} Z" fill="#1A0810" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>')
        body += f'<ellipse cx="{c}" cy="{c}" rx="24" ry="28" fill="url(#sd)" stroke="{INK}" stroke-width="4.5"/>'
        body += f'<path d="M {c} {c - 22} Q {c + 6} {c} {c} {c + 22}" fill="none" stroke="{EMBER}" stroke-width="3" opacity="0.9"/>'
    else:
        defs += radial("sd", [(0, "#FFFFFF", 1), (0.5, "#FFC2DC", 1), (1, "#F07AAE", 1)], cy="35%")
        body = f'<circle cx="{c}" cy="{c}" r="32" fill="#FFB3E0" opacity="0.5" filter="url(#sgl)"/>'
        for k in range(5):
            a = -math.pi / 2 + k * 2 * math.pi / 5
            px, py = c + math.cos(a) * 18, c + math.sin(a) * 18
            body += f'<ellipse cx="{px:.1f}" cy="{py:.1f}" rx="15" ry="11" transform="rotate({math.degrees(a):.0f} {px:.1f} {py:.1f})" fill="url(#sd)" stroke="{INK}" stroke-width="3.5"/>'
        body += f'<circle cx="{c}" cy="{c}" r="11" fill="#FFE27A" stroke="{INK}" stroke-width="3.5"/>'
        body += f'<circle cx="{c - 3}" cy="{c - 3}" r="3.5" fill="#FFFFFF" opacity="0.8"/>'
    render(name, body, defs, size, size)


def charm(name="ent_charm", size=110):
    c = size / 2
    defs = radial("ch", [(0, "#FFFFFF", 1), (0.5, "#CFEFFF", 1), (1, "#7CB8F0", 1)], cx="35%", cy="35%", r="70%")
    defs += blur_filter("cgl", 9)
    moon = (f"M {c + 10} {c - 34} A 36 36 0 1 0 {c + 10} {c + 34} "
            f"A 30 30 0 0 1 {c + 10} {c - 34} Z")
    body = f'<circle cx="{c}" cy="{c}" r="40" fill="#9FDCFF" opacity="0.55" filter="url(#cgl)"/>'
    body += f'<path d="{moon}" fill="url(#ch)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    body += f'<path d="M {c + 20} {c - 16} l 3 8 l 8 3 l -8 3 l -3 8 l -3 -8 l -8 -3 l 8 -3 Z" fill="#FFFFFF" stroke="{INK}" stroke-width="2"/>'
    body += f'<circle cx="{c - 14}" cy="{c - 14}" r="4" fill="#FFFFFF" opacity="0.8"/>'
    render(name, body, defs, size, size)


def boss_bat(name="ent_boss", size=220):
    d = ("M 110 130 C 92 108, 66 96, 10 86 C 28 100, 30 116, 22 138 C 42 128, 62 132, 70 148 C 80 134, 96 134, 110 144 "
         "C 124 134, 140 134, 150 148 C 158 132, 178 128, 198 138 C 190 116, 192 100, 210 86 C 154 96, 128 108, 110 130 Z")
    defs = linear("bb", [(0, "#4A1030", 1), (1, "#12040C", 1)]) + blur_filter("bgl2", 12) + blur_filter("eb", 4)
    body = f'<path d="{d}" fill="#FF2A10" opacity="0.55" filter="url(#bgl2)"/>'
    body += f'<path d="{d}" fill="url(#bb)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    for x1, y1 in [(30, 100), (52, 104), (168, 104), (190, 100)]:
        body += f'<path d="M 110 128 Q {(110 + x1) / 2} {y1 - 6} {x1} {y1}" fill="none" stroke="#06010A" stroke-width="3" opacity="0.7"/>'
    # crown of horns
    for k, (x, h) in enumerate([(88, 40), (99, 54), (110, 62), (121, 54), (132, 40)]):
        body += f'<path d="M {x - 6} 116 L {x} {116 - h} L {x + 6} 116 Z" fill="#1A0410" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    body += f'<ellipse cx="110" cy="124" rx="26" ry="20" fill="#2A0A1A" stroke="{INK}" stroke-width="4"/>'
    for x in (98, 110, 122):
        body += f'<ellipse cx="{x}" cy="{120 if x != 110 else 112}" rx="9" ry="9" fill="#FF3A1A" opacity="0.6" filter="url(#eb)"/>'
        body += f'<ellipse cx="{x}" cy="{120 if x != 110 else 112}" rx="4" ry="5" fill="#FFC04A"/>'
    body += '<path d="M 100 134 L 103 144 L 106 134 M 114 134 L 117 144 L 120 134" fill="#FFF6E0" stroke="#FFF6E0" stroke-width="2"/>'
    render(name, body, defs, size, size)


def ui_icons():
    star = "M 32 4 L 40 23 L 60 24 L 44 37 L 50 57 L 32 46 L 14 57 L 20 37 L 4 24 L 24 23 Z"
    defs = radial("st", [(0, "#FFF6C0", 1), (0.6, "#FFD25A", 1), (1, "#F0A020", 1)], cy="35%")
    render("ui_star", f'<path d="{star}" fill="url(#st)" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>'
           '<ellipse cx="25" cy="22" rx="5" ry="3" fill="#FFFFFF" opacity="0.7" transform="rotate(-30 25 22)"/>', defs, 64, 64)
    render("ui_star_empty", f'<path d="{star}" fill="#3A2440" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>', "", 64, 64)
    lock = (f'<path d="M 20 30 L 20 22 C 20 10, 44 10, 44 22 L 44 30" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>'
            f'<path d="M 20 30 L 20 22 C 20 10, 44 10, 44 22 L 44 30" fill="none" stroke="#9A8AA8" stroke-width="5" stroke-linecap="round"/>'
            f'<rect x="12" y="28" width="40" height="30" rx="6" fill="#6A5A7A" stroke="{INK}" stroke-width="4.5"/>'
            f'<circle cx="32" cy="42" r="5" fill="{INK}"/>')
    render("ui_lock", lock, "", 64, 64)
    pause = (f'<circle cx="32" cy="32" r="28" fill="#3A1640" stroke="{INK}" stroke-width="5"/>'
             f'<rect x="21" y="19" width="8" height="26" rx="3" fill="#FFFFFF"/><rect x="35" y="19" width="8" height="26" rx="3" fill="#FFFFFF"/>')
    render("ui_pause", pause, "", 64, 64)


def entities():
    bomb()
    carver("ent_grub", True)
    carver("ent_slug", False)
    wisp()
    hunter_bat()
    huggy_puff()
    nest("ent_nest_scary", True)
    nest("ent_nest_cute", False)
    seed("ent_seed_scary", True)
    seed("ent_seed_cute", False)
    charm()
    boss_bat()
    ui_icons()


# ------------------------------------------------------------------ zones, idols, crown

def _icon(name, body, defs="", size=96):
    render(name, body, defs, size, size)


def zone_icons():
    ring = f'<circle cx="48" cy="48" r="40" fill="#2A1430" stroke="{INK}" stroke-width="5"/>'
    hl = '<ellipse cx="36" cy="30" rx="12" ry="6" fill="#FFFFFF" opacity="0.18" transform="rotate(-30 36 30)"/>'
    W_ = "#FFF4FA"
    # hold: a banner flag
    _icon("zi_hold", ring + f'<path d="M 34 24 L 34 74" stroke="{W_}" stroke-width="6" stroke-linecap="round"/>'
          f'<path d="M 36 26 C 50 20, 58 34, 70 28 L 70 52 C 58 58, 50 44, 36 50 Z" fill="#FFD25A" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>' + hl)
    # swift: double chevron
    _icon("zi_swift", ring + f'<path d="M 26 32 L 42 48 L 26 64 M 46 32 L 62 48 L 46 64" fill="none" stroke="#9FF0FF" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>'
          f'<path d="M 66 34 L 74 48 L 66 62" fill="none" stroke="#9FF0FF" stroke-width="5" stroke-linecap="round" opacity="0.6"/>' + hl)
    # sluggish: snail
    _icon("zi_slow", ring + f'<path d="M 20 66 C 20 58, 30 58, 40 58 L 74 58 C 78 58, 78 66, 72 66 Z" fill="#9AD06A" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
          f'<path d="M 26 60 C 24 50, 28 42, 30 40 M 30 40 L 27 32 M 30 40 L 35 33" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>'
          f'<circle cx="27" cy="31" r="2.5" fill="{INK}"/><circle cx="36" cy="32" r="2.5" fill="{INK}"/>'
          f'<circle cx="54" cy="44" r="16" fill="#E8B070" stroke="{INK}" stroke-width="3.5"/>'
          f'<path d="M 54 44 m 0 -6 a 6 6 0 1 1 -6 6 a 11 11 0 1 1 11 11" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>' + hl)
    # straight: ruler arrow
    _icon("zi_straight", ring + f'<path d="M 22 62 L 66 30" stroke="{W_}" stroke-width="7" stroke-linecap="round"/>'
          f'<path d="M 54 28 L 70 27 L 68 43" fill="none" stroke="{W_}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>' + hl)
    # arc: curved arrow
    _icon("zi_arc", ring + f'<path d="M 24 64 C 26 34, 50 24, 68 32" fill="none" stroke="{W_}" stroke-width="7" stroke-linecap="round"/>'
          f'<path d="M 58 24 L 70 32 L 60 42" fill="none" stroke="{W_}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>' + hl)
    # curly: spiral
    pts = []
    for k in range(0, 200):
        t = k / 199 * 3.2 * math.pi * 2 / 2
        r = 2 + t * 3.4
        pts.append(f"{48 + math.cos(t) * r:.1f},{48 + math.sin(t) * r:.1f}")
    _icon("zi_curly", ring + f'<polyline points="{" ".join(pts)}" fill="none" stroke="{W_}" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>' + hl)
    # true: quill
    _icon("zi_true", ring + f'<path d="M 66 22 C 44 30, 32 48, 28 70 C 40 56, 54 50, 70 26 Z" fill="#FFF4FA" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
          f'<path d="M 28 70 L 24 76" stroke="{W_}" stroke-width="4" stroke-linecap="round"/><path d="M 34 60 L 60 32" stroke="#C8B0F0" stroke-width="2.5"/>' + hl)
    # haste: lightning
    _icon("zi_haste", ring + f'<path d="M 54 18 L 30 52 L 46 52 L 40 78 L 66 42 L 50 42 Z" fill="#FF6A3A" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>' + hl)
    # calm: sleepy moon
    _icon("zi_calm", ring + f'<path d="M 56 24 A 24 24 0 1 0 64 64 A 18 18 0 1 1 56 24 Z" fill="#CFEFFF" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
          f'<path d="M 58 30 L 68 30 L 58 40 L 68 40" fill="none" stroke="{W_}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>' + hl)


def idols():
    defs = blur_filter("ig", 8)
    # cute: candy-heart idol on a striped pedestal
    defs_c = defs + radial("ih", [(0, "#FFFFFF", 1), (0.45, "#FF9DBA", 1), (1, "#D9406E", 1)], cx="38%", cy="32%", r="70%")
    defs_c += linear("ip", [(0, "#C9F2FF", 1), (1, "#8FC8F0", 1)])
    heart = "M 60 70 C 30 50, 26 30, 36 20 C 46 10, 58 16, 60 26 C 62 16, 74 10, 84 20 C 94 30, 90 50, 60 70 Z"
    b = f'<ellipse cx="60" cy="58" rx="40" ry="38" fill="#FFB3E0" opacity="0.55" filter="url(#ig)"/>'
    b += f'<path d="M 38 76 L 82 76 L 78 104 L 42 104 Z" fill="url(#ip)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    for x in (48, 60, 72):
        b += f'<path d="M {x} 78 L {x - 4} 102" stroke="#FFFFFF" stroke-width="4" opacity="0.7"/>'
    b += f'<rect x="32" y="70" width="56" height="10" rx="4" fill="#FF9DBA" stroke="{INK}" stroke-width="4"/>'
    b += f'<path d="{heart}" fill="url(#ih)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    b += '<ellipse cx="46" cy="30" rx="7" ry="4.5" fill="#FFFFFF" opacity="0.8" transform="rotate(-35 46 30)"/>'
    b += f'<circle cx="52" cy="42" r="3.5" fill="{INK}"/><circle cx="68" cy="42" r="3.5" fill="{INK}"/><path d="M 55 50 Q 60 54 65 50" fill="none" stroke="{INK}" stroke-width="2.5" stroke-linecap="round"/>'
    render("ent_idol_cute", b, defs_c, 120, 120)
    # scary: horned bone lantern totem with glowing eyes
    defs_s = defs + radial("is", [(0, "#F4EAD0", 1), (1, "#B8A888", 1)], cx="40%", cy="30%", r="70%")
    defs_s += linear("ipd", [(0, "#3A2A36", 1), (1, "#140A12", 1)])
    b = f'<ellipse cx="60" cy="56" rx="40" ry="40" fill="#FF3A1A" opacity="0.5" filter="url(#ig)"/>'
    b += f'<path d="M 36 78 L 84 78 L 80 106 L 40 106 Z" fill="url(#ipd)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    b += f'<path d="M 46 84 L 74 84 M 48 94 L 72 94" stroke="{EMBER}" stroke-width="2.5" opacity="0.7"/>'
    b += f'<path d="M 40 36 C 30 26, 26 14, 30 6 C 36 16, 42 22, 48 26 Z M 80 36 C 90 26, 94 14, 90 6 C 84 16, 78 22, 72 26 Z" fill="#2A1A20" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>'
    b += f'<path d="M 38 46 C 38 24, 82 24, 82 46 C 82 60, 74 70, 70 76 L 50 76 C 46 70, 38 60, 38 46 Z" fill="url(#is)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
    b += f'<circle cx="50" cy="48" r="9" fill="#FF3A1A" opacity="0.6" filter="url(#ig)"/><circle cx="70" cy="48" r="9" fill="#FF3A1A" opacity="0.6" filter="url(#ig)"/>'
    b += f'<path d="M 42 46 L 56 50 L 54 56 L 44 54 Z M 78 46 L 64 50 L 66 56 L 76 54 Z" fill="#1A0408"/>'
    b += '<circle cx="50" cy="51" r="2.6" fill="#FFC04A"/><circle cx="70" cy="51" r="2.6" fill="#FFC04A"/>'
    b += f'<path d="M 56 62 L 60 58 L 64 62 Z" fill="#1A0408"/><path d="M 50 70 L 53 66 L 56 70 L 60 66 L 64 70 L 67 66 L 70 70" fill="none" stroke="#1A0408" stroke-width="2.5"/>'
    render("ent_idol_scary", b, defs_s, 120, 120)


def crown():
    defs = linear("cg", [(0, "#FFF6C0", 1), (0.5, "#FFD25A", 1), (1, "#E09A20", 1)])
    d = "M 8 40 L 6 14 L 20 26 L 32 6 L 44 26 L 58 14 L 56 40 Z"
    b = f'<path d="{d}" fill="url(#cg)" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
    b += f'<rect x="7" y="36" width="50" height="9" rx="3" fill="#E09A20" stroke="{INK}" stroke-width="3.5"/>'
    b += f'<circle cx="32" cy="30" r="4.5" fill="#E0204E" stroke="{INK}" stroke-width="2"/><circle cx="18" cy="33" r="3" fill="#7FD3F0" stroke="{INK}" stroke-width="1.5"/><circle cx="46" cy="33" r="3" fill="#7FD3F0" stroke="{INK}" stroke-width="1.5"/>'
    b += '<ellipse cx="22" cy="20" rx="3" ry="1.8" fill="#FFFFFF" opacity="0.8"/>'
    render("ent_crown", b, defs, 64, 50)


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
    entities()
    zone_icons()
    idols()
    crown()
    print("ok", len(LAYERS) + len(ARM_PIVOTS) + 6, "sprites")
    # visible-rect crops for the big layers (GPU fill-rate saver)
    import runpy
    runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_crops.py"), run_name="__main__")
