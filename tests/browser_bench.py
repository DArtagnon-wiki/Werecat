"""Frame-rate benchmark for the exported web build on a simulated weak GPU.

Chrome's SwiftShader renders WebGL on the CPU, so fill-rate-heavy shaders
slow it down much like a budget phone GPU. Frames are counted with
requestAnimationFrame (Godot's web main loop runs once per rAF).

Usage: python3 tests/browser_bench.py [build_dir] [query] [dpr] [seconds]
  e.g. python3 tests/browser_bench.py build/web "?gfx=lite" 3 20
Prints the fps and any [perf] lines the game logs.
"""
import asyncio
import functools
import http.server
import os
import shutil
import sys
import threading

from playwright.async_api import async_playwright

BUILD = sys.argv[1] if len(sys.argv) > 1 else "build/web"
QUERY = sys.argv[2] if len(sys.argv) > 2 else ""
DPR = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
SECONDS = int(sys.argv[4]) if len(sys.argv) > 4 else 20
WARMUP = 8

COUNTER = """
window.__frames = 0;
(function tick() { window.__frames++; requestAnimationFrame(tick); })();
"""


def serve(directory):
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass
    handler = functools.partial(Quiet, directory=directory)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def chrome_path():
    for name in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser"):
        p = shutil.which(name)
        if p:
            return p
    return None


async def main():
    srv = serve(os.path.abspath(BUILD))
    url = f"http://127.0.0.1:{srv.server_address[1]}/index.html{QUERY}"
    logs = []
    async with async_playwright() as p:
        kw = {"headless": True, "args": ["--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                                         "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"]}
        exe = chrome_path()
        if exe:
            kw["executable_path"] = exe
        browser = await p.chromium.launch(**kw)
        ctx = await browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=DPR,
                                        is_mobile=True, has_touch=True)
        page = await ctx.new_page()
        page.on("console", lambda m: logs.append(m.text) if "[perf]" in m.text or "[gfx]" in m.text else None)
        await page.goto(url, wait_until="load", timeout=90000)
        await asyncio.sleep(WARMUP)
        await page.evaluate(COUNTER)
        f0 = await page.evaluate("window.__frames")
        await asyncio.sleep(SECONDS)
        f1 = await page.evaluate("window.__frames")
        if os.environ.get("SHOT"):
            await page.screenshot(path=os.environ["SHOT"])
        size = await page.evaluate("(() => { const c = document.querySelector('canvas'); return c.width + 'x' + c.height; })()")
        await browser.close()
    srv.shutdown()
    for line in logs[-12:]:
        print(line)
    print(f"RESULT query={QUERY or '-'} dpr={DPR} canvas={size} fps={(f1 - f0) / SECONDS:.1f}")


asyncio.run(main())
