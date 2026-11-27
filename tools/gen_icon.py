"""Android launcher icons from the werecat's own layers: its face over the
moon, cute on the left half and scary on the right.

Writes assets/icons/icon_192.png (legacy), icon_fg_432.png,
icon_bg_432.png and icon_mono_432.png (adaptive icon layers; Android masks them to a circle,
squircle or rounded square and keeps the middle 66% safe).

Usage: python3 tools/gen_icon.py   (after tools/gen_art.py)
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SP = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "assets", "icons")
os.makedirs(OUT, exist_ok=True)

CUTE = ["wc_ears_cute", "wc_head_cute", "wc_muzzle_cute", "wc_whiskers", "wc_eyes_cute", "wc_mouth_cute"]
SCARY = ["wc_horns", "wc_ears_scary", "wc_head_scary", "wc_muzzle_scary", "wc_whiskers", "wc_eyes_scary", "wc_eye_glow",
         "wc_mouth_scary", "wc_drool"]


def stack(names):
    base = None
    for n in names:
        im = Image.open(os.path.join(SP, n + ".png")).convert("RGBA")
        base = im if base is None else Image.alpha_composite(base, im)
    return base


cute = stack(CUTE)
scary = stack(SCARY)
w, h = cute.size
# split down the middle with a slightly jagged seam
mask = Image.new("L", (w, h), 0)
d = ImageDraw.Draw(mask)
pts = [(0, 0), (w // 2, 0)]
for k in range(13):
    y = int(h * k / 12)
    pts.append((w // 2 + (14 if k % 2 else -14), y))
pts += [(w // 2, h), (0, h)]
d.polygon(pts, fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(1.2))
face = Image.composite(cute, scary, mask)
bbox = face.getbbox()
face = face.crop(bbox)


def background(size):
    bg = Image.new("RGBA", (size, size))
    px = bg.load()
    for y in range(size):
        t = y / size
        top = (40, 30, 84)
        bot = (60, 10, 24)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = c + (255,)
    # half moon: pale on the cute side, blood red on the scary side
    moon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    md = ImageDraw.Draw(moon)
    r = int(size * 0.36)
    cx, cy = size // 2, int(size * 0.47)
    md.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 238, 214, 255))
    red = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(red).ellipse((cx - r, cy - r, cx + r, cy + r), fill=(214, 34, 30, 255))
    half = Image.new("L", (size, size), 0)
    ImageDraw.Draw(half).rectangle((cx, 0, size, size), fill=255)
    moon = Image.composite(red, moon, half)
    glow = moon.filter(ImageFilter.GaussianBlur(size * 0.05))
    bg = Image.alpha_composite(bg, glow)
    bg = Image.alpha_composite(bg, moon)
    return bg


def place(canvas_size, scale):
    fw = int(canvas_size * scale)
    fh = int(face.height * fw / face.width)
    f = face.resize((fw, fh), Image.LANCZOS)
    layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    layer.alpha_composite(f, ((canvas_size - fw) // 2, int(canvas_size * 0.53 - fh / 2)))
    return layer


# adaptive: foreground face inside the 66% safe zone, background moon + sky
fg = place(432, 0.58)
fg.save(os.path.join(OUT, "icon_fg_432.png"))
# themed-icon (monochrome) layer: the face silhouette, Android tints it
mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
mono.putalpha(fg.getchannel("A").point(lambda a: 255 if a > 100 else 0))
mono.save(os.path.join(OUT, "icon_mono_432.png"))
background(432).save(os.path.join(OUT, "icon_bg_432.png"))
# legacy square icon with rounded corners
leg = Image.alpha_composite(background(192), place(192, 0.8))
m = Image.new("L", (192, 192), 0)
ImageDraw.Draw(m).rounded_rectangle((0, 0, 191, 191), radius=36, fill=255)
leg.putalpha(m)
leg.save(os.path.join(OUT, "icon_192.png"))
# preview of how it looks masked to a circle
prev = Image.alpha_composite(background(432), fg)
cm = Image.new("L", (432, 432), 0)
ImageDraw.Draw(cm).ellipse((0, 0, 431, 431), fill=255)
prev.putalpha(cm)
prev.save("/tmp/icon_preview.png")
print("wrote icons to", os.path.normpath(OUT))
