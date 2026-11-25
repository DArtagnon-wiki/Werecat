"""Composites the werecat layers at several morph values for art review.
Mirrors the layer logic in scripts/werecat.gd (approximately).
Usage: python3 tools/preview_werecat.py out.png [m1 m2 ...]"""
import math
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(ROOT, "assets", "sprites")
sys.path.insert(0, os.path.join(ROOT, "tools"))
from gen_art import ARM_PIVOTS, HC  # noqa: E402


def L(name):
    return Image.open(os.path.join(SP, name + ".png")).convert("RGBA")


def ramp(m, a, b):
    return max(0.0, min(1.0, (m - a) / (b - a)))


def fade(img, a):
    if a >= 1:
        return img
    r, g, b, al = img.split()
    al = al.point(lambda v: int(v * a))
    return Image.merge("RGBA", (r, g, b, al))


def scaled(img, s, pivot):
    if s <= 0.001:
        return None
    w, h = img.size
    im = img.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)
    out = Image.new("RGBA", img.size)
    out.alpha_composite(im, (int(pivot[0] - pivot[0] * s), int(pivot[1] - pivot[1] * s)))
    return out


def seg_pose(canvas, name, at, ang, flip):
    w, h, px, py, dx, dy = ARM_PIVOTS[name]
    img = L(name)
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
        px, dx = w - px, w - dx
    # rotate around pivot
    big = Image.new("RGBA", (w * 3, h * 3 + w * 2))
    ox, oy = big.size[0] // 2 - px, big.size[1] // 2 - py
    big.alpha_composite(img, (ox, oy))
    rot = big.rotate(-math.degrees(ang), resample=Image.BICUBIC, center=(big.size[0] // 2, big.size[1] // 2))
    canvas.alpha_composite(rot, (int(at[0] - big.size[0] // 2), int(at[1] - big.size[1] // 2)))
    # distal joint position
    L_ = math.hypot(dx - px, dy - py)
    sgn = -1 if flip else 1
    return (at[0] + math.cos(ang) * L_ * sgn, at[1] + math.sin(ang) * L_ * (1 if not flip else 1))


# Arm pose for the RIGHT arm (screen right). Left arm = mirror image.
SHOULDER = (590, 620)


def arm_angles(raise_amt, strike):
    """Absolute angles (radians) for coxa, femur, tibia.
    raise_amt 0 = hidden/low, 1 = raised beside the face. strike 0..1."""
    a1 = math.radians(lerp(20, -50, raise_amt) + 30 * strike)
    a2 = math.radians(lerp(40, -70, raise_amt) + 80 * strike)
    a3 = math.radians(lerp(200, 155, raise_amt) - 75 * strike)
    return a1, a2, a3


def lerp(a, b, t):
    return a + (b - a) * t


def right_arm(raise_amt, strike):
    layer = Image.new("RGBA", (800, 800))
    p = SHOULDER
    for name, a in zip(("arm_coxa", "arm_femur", "arm_tibia"), arm_angles(raise_amt, strike)):
        w, h, px, py, dx, dy = ARM_PIVOTS[name]
        img = L(name)
        ln = math.hypot(dx - px, dy - py)
        size = int(ln * 2 + w) + 60
        big = Image.new("RGBA", (size, size))
        c = (size // 2, size // 2)
        big.alpha_composite(img, (c[0] - px, c[1] - py))
        rot = big.rotate(-math.degrees(a), resample=Image.BICUBIC, center=c)
        layer.alpha_composite(rot, (int(p[0] - c[0]), int(p[1] - c[1])))
        p = (p[0] + math.cos(a) * ln, p[1] + math.sin(a) * ln)
    return layer


def arms(canvas, m, strike=0.0):
    t = tier(m)
    if t < 2:
        return
    r = right_arm(1.0, strike)
    if t == 2:  # peeking: smaller, from behind the shoulders
        r = scaled(r, 0.72, SHOULDER)
    canvas.alpha_composite(r)
    canvas.alpha_composite(r.transpose(Image.FLIP_LEFT_RIGHT))


def tier(m):
    return 0 if m < 0.2 else 1 if m < 0.4 else 2 if m < 0.6 else 3 if m < 0.8 else 4


def werecat(m, blink=False, strike=0.0):
    t = tier(m)
    c = Image.new("RGBA", (800, 800))
    sp = scaled(L("wc_spikes"), [0, 0.7, 0.82, 0.92, 1.0][t], HC)
    if sp is not None:
        c.alpha_composite(sp)
    fur = ramp(m, 0.15, 0.65)
    c.alpha_composite(fade(L("wc_body_cute"), 1 - fur))
    c.alpha_composite(fade(L("wc_body_scary"), fur))
    arms(c, m, strike)
    c.alpha_composite(L("wc_ears_scary") if t >= 2 else L("wc_ears_cute"))
    hs = scaled(L("wc_horns"), [0, 0, 0.6, 0.85, 1.0][t], (400, 230))
    if hs is not None:
        c.alpha_composite(hs)
    c.alpha_composite(fade(L("wc_head_cute"), 1 - fur))
    c.alpha_composite(fade(L("wc_head_scary"), fur))
    c.alpha_composite(L("wc_muzzle_scary") if t >= 2 else L("wc_muzzle_cute"))
    if t <= 2:
        c.alpha_composite(fade(L("wc_whiskers"), 1.0 if t < 2 else 0.6))
    if t < 3:
        e = L("wc_eyes_blink") if blink else L("wc_eyes_cute")
        c.alpha_composite(e)
    else:
        c.alpha_composite(fade(L("wc_eye_glow"), 0.7 if t == 3 else 1.0))
        c.alpha_composite(L("wc_eyes_scary"))
    if t < 3:
        c.alpha_composite(L("wc_mouth_cute"))
    else:
        c.alpha_composite(L("wc_mouth_scary"))
        c.alpha_composite(L("wc_drool"))
    c.alpha_composite(L("wc_paws_scary") if t >= 2 else L("wc_paws"))
    return c


def bg(m):
    im = Image.new("RGBA", (800, 800))
    d = ImageDraw.Draw(im)
    for y in range(800):
        t = y / 800
        a = (int(40 - 30 * m + 20 * t), int(30 - 25 * m + 10 * t), int(70 - 55 * m + 10 * t))
        d.line([(0, y), (800, y)], fill=a + (255,))
    moon = (int(250 - 60 * m), int(240 - 200 * m), int(215 - 190 * m))
    d.ellipse([170, 80, 630, 540], fill=moon + (255,))
    d.rectangle([0, 690, 800, 800], fill=(18, 10, 24, 255))
    return im


if __name__ == "__main__":
    out = sys.argv[1]
    ms = [float(x) for x in sys.argv[2:]] or [0.0, 0.3, 0.5, 0.7, 0.9]
    tiles = []
    for m in ms:
        b = bg(m)
        b.alpha_composite(werecat(m, strike=1.0 if m > 0.95 else 0.0))
        tiles.append(b.resize((400, 400), Image.LANCZOS))
    sheet = Image.new("RGBA", (400 * len(tiles), 400))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, (400 * i, 0))
    sheet.convert("RGB").save(out)
