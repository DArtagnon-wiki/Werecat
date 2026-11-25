import math, random
from PIL import Image, ImageDraw, ImageFilter

S = 2
W, H = 480, 480
random.seed(7)

def P(x, y):
    return (x * S, y * S)

def lerp(a, b, t):
    return a + (b - a) * t

def lc(c1, c2, t):
    return tuple(int(lerp(a, b, t)) for a, b in zip(c1, c2))

def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))

def ease(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)

# timeline
CUTE, MORPH, SCARY, FADE = 14, 14, 30, 4
N = CUTE + MORPH + SCARY + FADE

FUR_C, FUR_S = (214, 168, 120), (58, 40, 42)
FURD_C, FURD_S = (160, 112, 72), (24, 14, 18)
FURL_C, FURL_S = (244, 220, 190), (92, 60, 60)
MANTIS = (70, 110, 40)
MANTIS_DARK = (28, 52, 18)
SPIKE = (230, 220, 190)

body_tufts = [(random.uniform(0, 2 * math.pi), random.uniform(0.85, 1.1), random.uniform(10, 18)) for _ in range(90)]
head_tufts = [(random.uniform(0, 2 * math.pi), random.uniform(0.85, 1.08), random.uniform(7, 12)) for _ in range(60)]
stars = [(random.uniform(0, W), random.uniform(0, 300), random.uniform(1, 2.2)) for _ in range(40)]
bats = [(random.uniform(0, 1), random.uniform(60, 200), random.uniform(0.6, 1.2)) for _ in range(5)]

def fluffy(d, cx, cy, rx, ry, tufts, t, m, col, dark, wobble):
    # spikes grow out of the fur as m rises
    if m > 0.05:
        for ang, rr, sz in tufts:
            L = sz * (0.4 + 2.6 * m) * (0.7 + 0.6 * ((ang * 7) % 1))
            bx = cx + math.cos(ang) * rx * rr
            by = cy + math.sin(ang) * ry * rr
            tip = (bx + math.cos(ang) * L, by + math.sin(ang) * L)
            pa = ang + math.pi / 2
            w = sz * 0.6
            d.polygon([P(bx + math.cos(pa) * w, by + math.sin(pa) * w), P(*tip),
                       P(bx - math.cos(pa) * w, by - math.sin(pa) * w)], fill=dark)
    for ang, rr, sz in tufts:
        wv = math.sin(t * 2 * math.pi + ang * 3) * wobble
        x = cx + math.cos(ang) * rx * rr + wv
        y = cy + math.sin(ang) * ry * rr
        d.ellipse([*P(x - sz, y - sz), *P(x + sz, y + sz)], fill=dark)
    for ang, rr, sz in tufts:
        wv = math.sin(t * 2 * math.pi + ang * 3) * wobble
        x = cx + math.cos(ang) * rx * rr * 0.92 + wv
        y = cy + math.sin(ang) * ry * rr * 0.92
        r = sz * 0.8
        d.ellipse([*P(x - r, y - r), *P(x + r, y + r)], fill=col)
    d.ellipse([*P(cx - rx * 0.9, cy - ry * 0.9), *P(cx + rx * 0.9, cy + ry * 0.9)], fill=col)

def seg(d, a, b, width, col):
    d.line([P(*a), P(*b)], fill=col, width=max(1, int(width * S)))
    r = width / 2
    for p in (a, b):
        d.ellipse([*P(p[0] - r, p[1] - r), *P(p[0] + r, p[1] + r)], fill=col)

def spikes(d, a, b, n, side, length):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy) or 1
    nx, ny = -dy / L * side, dx / L * side
    for i in range(1, n + 1):
        f = i / (n + 1)
        bx, by = a[0] + dx * f, a[1] + dy * f
        tip = (bx + nx * length + dx / L * length * 0.5, by + ny * length + dy / L * length * 0.5)
        d.polygon([P(bx - dx / L * 3, by - dy / L * 3), P(*tip), P(bx + dx / L * 3, by + dy / L * 3)], fill=SPIKE)

def pt(o, ang, L):
    return (o[0] + math.cos(ang) * L, o[1] + math.sin(ang) * L)

def raptor_arm(d, shoulder, side, ph, g):
    if ph < 0.55:
        r, s = 0.5 - 0.5 * math.cos(ph / 0.55 * math.pi), 0
    elif ph < 0.68:
        k = (ph - 0.55) / 0.13
        r, s = 1 - k, k
    else:
        r, s = 0, 1 - (ph - 0.68) / 0.32
    def M(p):
        return (shoulder[0] + side * (p[0] - shoulder[0]), p[1])
    coxa_a = math.radians(-60 - 20 * r + 30 * s)
    e = pt(shoulder, coxa_a, (50 + 10 * r) * g)
    fem_a = math.radians(-40 - 30 * r + 40 * s)
    k_ = pt(e, fem_a, 85 * g)
    tib_a = fem_a + math.radians(155 - 135 * s)
    c = pt(k_, tib_a, 62 * g)
    h = pt(c, tib_a + math.radians(80), 18 * g)
    elbow, knee, claw, hook = M(e), M(k_), M(c), M(h)
    seg(d, shoulder, elbow, 14 * g, MANTIS_DARK)
    seg(d, shoulder, elbow, 10 * g, MANTIS)
    seg(d, elbow, knee, 19 * g, MANTIS_DARK)
    seg(d, elbow, knee, 13 * g, MANTIS)
    spikes(d, elbow, knee, 7, -side, 14 * g)
    seg(d, knee, claw, 10 * g, MANTIS_DARK)
    seg(d, knee, claw, 7 * g, MANTIS)
    spikes(d, knee, claw, 5, side, 9 * g)
    seg(d, claw, hook, 6 * g, MANTIS_DARK)

def walk_leg(d, hip, side, t, phase, reach, g):
    ph = (t + phase) % 1.0
    sw = math.sin(ph * 2 * math.pi)
    up = max(0, math.cos(ph * 2 * math.pi)) * 14
    foot_full = (hip[0] + side * reach + sw * 14, 440 - up * 0.4)
    knee_full = (hip[0] + side * reach * 0.55 + sw * 6, hip[1] - 60 - up)
    knee = (lerp(hip[0], knee_full[0], g), lerp(hip[1], knee_full[1], g))
    foot = (lerp(hip[0], foot_full[0], g), lerp(hip[1], foot_full[1], g))
    seg(d, hip, knee, 9, MANTIS_DARK)
    seg(d, hip, knee, 6, MANTIS)
    seg(d, knee, foot, 7, MANTIS_DARK)
    seg(d, knee, foot, 4, MANTIS)
    spikes(d, knee, foot, 3, side, 6 * g)

def frame(i):
    # monster-ness m, local time t
    if i < CUTE:
        m = 0.0
    elif i < CUTE + MORPH:
        m = ease((i - CUTE) / (MORPH - 1))
    else:
        m = 1.0
    t = i / 15.0
    fade = clamp((i - (CUTE + MORPH + SCARY) + 1) / FADE) if i >= CUTE + MORPH + SCARY else 0
    flash = 1.0 if i in (CUTE + 7, CUTE + 8) else 0.0
    shake = (random.uniform(-4, 4) * m, random.uniform(-3, 3) * m) if i >= CUTE + 5 else (0, 0)
    sx, sy = shake

    # --- sky ---
    top = lc((70, 60, 120), (10, 0, 4), m)
    bot = lc((200, 150, 190), (90, 6, 10), m)
    img = Image.new("RGB", (W * S, H * S))
    d = ImageDraw.Draw(img)
    for y in range(0, H, 4):
        d.rectangle([*P(0, y), *P(W, y + 4)], fill=lc(top, bot, y / H))
    for x, y, r in stars:
        c = lc((255, 250, 220), top, m)
        d.ellipse([*P(x - r, y - r), *P(x + r, y + r)], fill=c)

    # --- blood moon rising ---
    mr = ease((i - CUTE - 2) / (MORPH + 2)) if i >= CUTE + 2 else 0
    if mr > 0:
        mx, my, R = 240, lerp(560, 150, mr), 125
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse([*P(mx - R - 50, my - R - 50), *P(mx + R + 50, my + R + 50)], fill=(255, 20, 10, 150))
        glow = glow.filter(ImageFilter.GaussianBlur(30 * S))
        img.paste(glow, (0, 0), glow)
        d = ImageDraw.Draw(img)
        d.ellipse([*P(mx - R, my - R), *P(mx + R, my + R)], fill=(176, 24, 18))
        # craters
        for ox, oy, cr in ((-40, -30, 22), (35, 20, 16), (-10, 50, 12), (50, -45, 10), (-60, 25, 9)):
            d.ellipse([*P(mx + ox - cr, my + oy - cr), *P(mx + ox + cr, my + oy + cr)], fill=(140, 14, 12))
        # bats crossing the moon
        if m > 0.9:
            for b0, by, sp in bats:
                bx = ((b0 + t * 0.25 * sp) % 1.2 - 0.1) * W
                fl = math.sin(t * 2 * math.pi * 3 + b0 * 10) * 6
                d.polygon([P(bx - 14, by - fl), P(bx - 4, by + 2), P(bx, by - 3), P(bx + 4, by + 2), P(bx + 14, by - fl), P(bx, by + 5)], fill=(8, 0, 2))

    # dead hills
    d.polygon([P(0, 400), P(90, 370), P(200, 395), P(330, 360), P(480, 390), P(480, 480), P(0, 480)], fill=lc((90, 70, 110), (14, 2, 4), m))
    d.rectangle([*P(0, 438), *P(W, H)], fill=lc((70, 56, 90), (6, 0, 2), m))

    fur, furd, furl = lc(FUR_C, FUR_S, m), lc(FURD_C, FURD_S, m), lc(FURL_C, FURL_S, m)
    g = ease((m - 0.25) / 0.6)          # limb growth
    bob = math.sin(t * 2 * math.pi) * (2 + 2 * m)
    cx, cy = 240 + sx, 330 + sy + bob - 25 * g

    # walking legs
    if g > 0:
        for side in (-1, 1):
            walk_leg(d, (cx + side * 30, cy + 40), side, t, 0.0 if side < 0 else 0.5, 130, g)
            walk_leg(d, (cx + side * 55, cy + 20), side, t, 0.5 if side < 0 else 0.0, 165, g)

    d.ellipse([*P(cx - 120, 432), *P(cx + 120, 448)], fill=lc((60, 46, 80), (0, 0, 0), m))

    # tail
    tail = [(cx + 90 + a * 50, cy - 10 - a * 70 + math.sin(t * 2 * math.pi * (1 + m) + a * 3) * 12 * a, 16 - a * 4) for a in [k / 9 for k in range(10)]]
    for tx, ty, r in tail:
        d.ellipse([*P(tx - r - 3, ty - r - 3), *P(tx + r + 3, ty + r + 3)], fill=furd)
    if m > 0.3:   # stinger-like spike on the tail tip
        tx, ty, _ = tail[-1]
        L = 30 * m
        d.polygon([P(tx - 8, ty), P(tx + 8, ty), P(tx + 4, ty - L)], fill=SPIKE)
    for tx, ty, r in tail:
        d.ellipse([*P(tx - r, ty - r), *P(tx + r, ty + r)], fill=fur)

    fluffy(d, cx, cy, 95, 72, body_tufts, t, m, fur, furd, 2)
    d.ellipse([*P(cx - 45, cy - 10), *P(cx + 45, cy + 55)], fill=furl)
    if m < 0.6:  # little cute paws
        for side in (-1, 1):
            px = cx + side * 30
            d.ellipse([*P(px - 18, cy + 50), *P(px + 18, cy + 72)], fill=lc(FURL_C, FURD_S, m))

    # head
    hx, hy = cx, cy - 95 + bob * 0.5
    flop = math.sin(t * 2 * math.pi) * 3
    for side in (-1, 1):
        d.ellipse([*P(hx + side * 52 - 16, hy - 10 + flop), *P(hx + side * 52 + 16, hy + 48 + flop)], fill=furd)
    ear_h = 85 + 30 * m
    for side in (-1, 1):
        d.polygon([P(hx + side * 18, hy - 40), P(hx + side * (52 + 10 * m), hy - ear_h), P(hx + side * 50, hy - 25)], fill=furd)
        d.polygon([P(hx + side * 26, hy - 40), P(hx + side * (48 + 9 * m), hy - ear_h + 13), P(hx + side * 46, hy - 32)], fill=lc((240, 150, 170), (120, 0, 10), m))
    fluffy(d, hx, hy, 50, 44, head_tufts, t, m * 0.8, fur, furd, 1.5)

    # horns poke out
    if m > 0.4:
        hm = (m - 0.4) / 0.6
        for side in (-1, 1):
            b1, b2 = (hx + side * 14, hy - 38), (hx + side * 30, hy - 34)
            tip = (hx + side * (40 + 18 * hm), hy - 40 - 50 * hm)
            d.polygon([P(*b1), P(*tip), P(*b2)], fill=(30, 20, 20))

    # eyes
    blink = i in (8, 9)
    if m < 0.5:
        for side in (-1, 1):
            ex, ey = hx + side * 20, hy - 6
            if blink:
                d.arc([*P(ex - 12, ey - 6), *P(ex + 12, ey + 8)], 20, 160, fill=(30, 20, 30), width=3 * S)
            else:
                r = 14 * (1 - m)
                d.ellipse([*P(ex - r, ey - r), *P(ex + r, ey + r)], fill=(30, 20, 40))
                d.ellipse([*P(ex - r * 0.55, ey - r * 0.75), *P(ex - r * 0.05, ey - r * 0.25)], fill=(255, 255, 255))
                d.ellipse([*P(ex + r * 0.2, ey + r * 0.2), *P(ex + r * 0.45, ey + r * 0.45)], fill=(255, 255, 255))
        # blush
        for side in (-1, 1):
            bx = hx + side * 34
            d.ellipse([*P(bx - 9, hy + 10), *P(bx + 9, hy + 18)], fill=lc((250, 160, 170), fur, m * 2))
    else:
        em = (m - 0.5) / 0.5
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        pulse = 0.75 + 0.25 * math.sin(t * 2 * math.pi * 2)
        for side in (-1, 1):
            ex, ey = hx + side * 20, hy - 8
            gd.ellipse([*P(ex - 24, ey - 20), *P(ex + 24, ey + 20)], fill=(255, 0, 0, int(200 * pulse * em)))
        glow = glow.filter(ImageFilter.GaussianBlur(7 * S))
        img.paste(glow, (0, 0), glow)
        d = ImageDraw.Draw(img)
        for side in (-1, 1):
            ex, ey = hx + side * 20, hy - 8
            inner, outer = ex - side * 13, ex + side * 13
            d.polygon([P(inner, ey - 1), P(outer, ey - 9), P(outer - side * 2, ey + 7), P(inner, ey + 6)], fill=(255, 40, 20))
            d.ellipse([*P(ex - 2, ey - 7), *P(ex + 2, ey + 7)], fill=(0, 0, 0))
            d.line([P(inner - side * 2, ey - 3), P(outer + side * 4, ey - 16)], fill=(10, 0, 0), width=4 * S)

    # snout / nose
    d.ellipse([*P(hx - 26, hy + 2), *P(hx + 26, hy + 36)], fill=furl)
    d.polygon([P(hx - 9, hy + 8), P(hx + 9, hy + 8), P(hx, hy + 17)], fill=lc((240, 120, 150), (10, 0, 0), m))

    # mouth
    if m < 0.5:
        d.arc([*P(hx - 10, hy + 13), *P(hx, hy + 25)], 0, 180, fill=(60, 30, 30), width=2 * S)
        d.arc([*P(hx, hy + 13), *P(hx + 10, hy + 25)], 0, 180, fill=(60, 30, 30), width=2 * S)
    else:
        em = (m - 0.5) / 0.5
        jaw = (10 + 8 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2))) * em
        w = 22 * em + 8
        d.ellipse([*P(hx - w, hy + 19), *P(hx + w, hy + 26 + jaw)], fill=(60, 0, 8))
        for fx in (-16, -9, -3, 3, 9, 16):
            if abs(fx) < w - 2:
                L = 12 if abs(fx) == 16 or abs(fx) == 9 else 7
                d.polygon([P(hx + fx - 3, hy + 20), P(hx + fx + 3, hy + 20), P(hx + fx, hy + 20 + L * em)], fill=(250, 248, 230))
        for fx in (-10, 0, 10):
            if abs(fx) < w - 2:
                yb = hy + 26 + jaw
                d.polygon([P(hx + fx - 3, yb), P(hx + fx + 3, yb), P(hx + fx, yb - 8 * em)], fill=(250, 248, 230))
        # drool drip
        dl = 10 + 10 * ((t * 2) % 1)
        d.line([P(hx + 12, hy + 26 + jaw * 0.6), P(hx + 12, hy + 26 + jaw * 0.6 + dl * em)], fill=(160, 10, 20), width=3 * S)

    # whiskers
    wc = lc((255, 245, 230), (120, 100, 100), m)
    for side in (-1, 1):
        for k in (-1, 0, 1):
            d.line([P(hx + side * 22, hy + 18 + k * 4), P(hx + side * (58 + 10 * m), hy + 12 + k * 9 - 6 * m)], fill=wc, width=1 * S)

    # mantis arms burst out
    if g > 0:
        ph = ((i - CUTE - MORPH) / 15.0) % 1.0 if i >= CUTE + MORPH else 0.4 * g
        raptor_arm(d, (cx - 60, cy - 30), -1, ph, g)
        raptor_arm(d, (cx + 60, cy - 30), 1, (ph + 0.05) % 1, g)

    # vignette darkness
    if m > 0:
        vig = Image.new("L", (W * S, H * S), 0)
        vd = ImageDraw.Draw(vig)
        vd.ellipse([*P(-60, -40), *P(W + 60, H + 40)], fill=255)
        vig = vig.filter(ImageFilter.GaussianBlur(40 * S))
        dark = Image.new("RGB", img.size, (0, 0, 0))
        mask = vig.point(lambda v: int((255 - v) * 0.85 * m))
        img.paste(dark, (0, 0), mask)

    out = img.resize((W, H), Image.LANCZOS)
    if flash:
        out = Image.blend(out, Image.new("RGB", out.size, (255, 230, 230)), 0.7)
    if fade:
        out = Image.blend(out, Image.new("RGB", out.size, (0, 0, 0)), fade)
    return out

frames = [frame(i) for i in range(N)]
durs = []
for i in range(N):
    if i < CUTE: durs.append(110)
    elif i < CUTE + MORPH: durs.append(90)
    elif i < CUTE + MORPH + SCARY: durs.append(70)
    else: durs.append(100)
durs[CUTE - 1] = 600   # dramatic pause before the reveal
pal = [f.convert("P", palette=Image.ADAPTIVE, colors=160) for f in frames]
pal[0].save("scary_catdog.gif", save_all=True, append_images=pal[1:], duration=durs, loop=0, optimize=True, disposal=2)
s = Image.new("RGB", (240 * 6, 240))
for k, fi in enumerate((3, 15, 20, 24, 30, 40)):
    s.paste(frames[fi].resize((240, 240)), (k * 240, 0))
s.save("strip2.png")
print(N, sum(durs))
