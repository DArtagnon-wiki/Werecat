"""Bakes the tiling noise texture used by the Lite shaders.

Lite mode looks the noise up instead of computing it per pixel, which is
most of the territory and sky shader cost on weak phone GPUs.

  R: 5-octave fbm of value noise, 8 lattice cells across   (smoke, craters, clouds)
  G: voronoi edge distance (d2 - d1) / 0.6, 8 cells across  (ember cracks)
  B: value noise, 32 cells across                           (warp x, flicker)
  A: value noise, 32 cells across, independent               (warp y)

Matches the procedural versions in territory.gdshader / background.gdshader:
  fbm(p)          ~= texture(noise, p / 8).r
  voronoi_edge(p) ~= texture(noise, p / 8).g * 0.6
  noise(p)        ~= texture(noise, p / 32).b

Usage: python3 tools/gen_noise.py  ->  assets/textures/noise.png
"""
import os

import numpy as np
from PIL import Image

N = 256
rng = np.random.default_rng(7)


def value_noise(cells, seed):
    """Tileable smoothstep value noise with `cells` lattice cells across N px."""
    r = np.random.default_rng(seed)
    lattice = r.random((cells, cells))
    coords = np.arange(N) * cells / N
    i = np.floor(coords).astype(int)
    f = coords - i
    u = f * f * (3 - 2 * f)
    i0, i1 = i % cells, (i + 1) % cells
    # rows (y) then columns (x)
    a = lattice[np.ix_(i0, i0)]
    b = lattice[np.ix_(i0, i1)]
    c = lattice[np.ix_(i1, i0)]
    d = lattice[np.ix_(i1, i1)]
    ux = u[None, :]
    uy = u[:, None]
    return (a * (1 - ux) + b * ux) * (1 - uy) + (c * (1 - ux) + d * ux) * uy


def fbm(base_cells, seed):
    v = np.zeros((N, N))
    amp = 0.5
    cells = base_cells
    for k in range(5):
        v += amp * value_noise(cells, seed + k)
        cells *= 2
        amp *= 0.5
    return v  # range ~0..0.97, same as the shader's fbm


def voronoi_edge(cells, seed):
    r = np.random.default_rng(seed)
    pts = r.random((cells, cells, 2))
    ys, xs = np.mgrid[0:N, 0:N] * (cells / N)
    d1 = np.full((N, N), 8.0)
    d2 = np.full((N, N), 8.0)
    cx = np.floor(xs).astype(int)
    cy = np.floor(ys).astype(int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            gx = cx + dx
            gy = cy + dy
            o = pts[gy % cells, gx % cells]
            px = gx + o[..., 0]
            py = gy + o[..., 1]
            d = np.hypot(px - xs, py - ys)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            d1 = np.where(closer, d, d1)
    return d2 - d1


r = fbm(8, 100)
g = np.clip(voronoi_edge(8, 200) / 0.6, 0, 1)
b = value_noise(32, 300)
a = value_noise(32, 400)
img = np.stack([r, g, b, a], axis=-1)
img = np.clip(np.round(img * 255), 0, 255).astype(np.uint8)
out = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "noise.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
Image.fromarray(img, "RGBA").save(out)
print("wrote", os.path.normpath(out))
