"""Browser soak test for the exported web build.

Serves build/web, opens it in headless Chrome as a phone (audio autoplay
allowed, so the music actually runs), and watches it for 45 seconds.
Fails if the page crashes, logs errors, or the JS heap grows past the limit.

Added after a real bug: music played as decoded samples plus a per-frame
seek churned ~200 MB/s and crashed Chrome tabs about 30 s after loading.

Usage: python3 tests/browser_soak.py [build_dir]   (needs: pip install playwright)
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
SECONDS = 45
HEAP_LIMIT_MB = 120


def serve(directory):
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)
    handler.log_message = lambda *a: None
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
    url = f"http://127.0.0.1:{srv.server_address[1]}/index.html"
    problems = []
    peak = 0
    async with async_playwright() as p:
        kw = {"headless": True, "args": ["--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                                         "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"]}
        exe = chrome_path()
        if exe:
            kw["executable_path"] = exe
        browser = await p.chromium.launch(**kw)
        ctx = await browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=1)
        page = await ctx.new_page()
        crashed = []
        page.on("crash", lambda: crashed.append(True))
        page.on("pageerror", lambda e: problems.append(f"page error: {e}"))
        page.on("console", lambda m: problems.append(f"console error: {m.text}")
                if m.type == "error" and "WebGL" not in m.text else None)
        await page.goto(url, wait_until="load", timeout=90000)
        for t in range(SECONDS):
            await asyncio.sleep(1)
            if crashed:
                problems.append(f"page CRASHED after {t + 1}s")
                break
            try:
                mb = await page.evaluate("performance.memory.usedJSHeapSize / 1e6")
            except Exception as e:  # noqa: BLE001
                problems.append(f"page stopped responding after {t + 1}s: {e}")
                break
            peak = max(peak, mb)
            if t % 5 == 4:
                print(f"t={t + 1:2d}s heap {mb:6.1f} MB (peak {peak:.1f})", flush=True)
        await browser.close()
    srv.shutdown()
    if peak > HEAP_LIMIT_MB:
        problems.append(f"JS heap peaked at {peak:.0f} MB (limit {HEAP_LIMIT_MB} MB)")
    for pr in problems:
        print("FAIL ", pr)
    print("browser soak:", "FAILED" if problems else f"ok, peak heap {peak:.0f} MB")
    sys.exit(1 if problems else 0)


asyncio.run(main())
