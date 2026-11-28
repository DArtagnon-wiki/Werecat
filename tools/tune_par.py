"""Sets each night's target time (par) for the third star from the bot's
winning runs. The bot draws instantly with perfect aim, so a person gets
1.5x its median winning time plus 3 s per wall it needed, at least 45 s,
rounded up to 5 s. Rewrites PAR in scripts/levels.gd and keeps the raw
measurements in tools/par_raw.json.

Usage: python3 tools/tune_par.py [tries]     measure, then set par
       python3 tools/tune_par.py --reuse     recompute from par_raw.json
"""
import json, math, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GODOT = os.environ.get("GODOT", "/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64")
LEVELS = os.path.join(ROOT, "scripts", "levels.gd")
reuse = len(sys.argv) > 1 and sys.argv[1] == "--reuse"
tries = int(sys.argv[1]) if len(sys.argv) > 1 and not reuse else 6
RAW = os.path.join(ROOT, "tools", "par_raw.json")


def run(a, b):
    out = subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tests/bot_test.gd", "--", "range", str(a), str(b), str(tries)],
                         capture_output=True, text=True, timeout=4000).stdout
    res = {}
    for line in out.splitlines():
        m = re.search(r"STAT (\S+) .*?win\s+(\d+)/\d+\s+claims\s+(-?\d+).*?t\s+([\d.-]+)s", line)
        if m and int(m.group(2)) > 0:
            res[m.group(1)] = (float(m.group(4)), int(m.group(3)))
    return res


if reuse:
    res = {k: tuple(v) for k, v in json.load(open(RAW)).items()}
else:
    with ThreadPoolExecutor(2) as ex:
        parts = list(ex.map(lambda ab: run(*ab), [(0, 49), (50, 99)]))
    res = {**parts[0], **parts[1]}
    json.dump(res, open(RAW, "w"), indent=0, sort_keys=True)
par = {}
for lid, (t, claims) in res.items():
    par[lid] = int(math.ceil(max(45.0, 1.5 * t + 3.0 * max(claims, 0)) / 5.0) * 5)
s = open(LEVELS).read()
def key(k):
    a, b = k.split("-")
    return int(a) * 10 + int(b)
items = sorted(par.items(), key=lambda kv: key(kv[0]))
lines = ["\t" + ", ".join(f'"{k}": {v}' for k, v in items[i:i + 5]) + "," for i in range(0, len(items), 5)]
s = re.sub(r"const PAR := \{.*?\}", "const PAR := {\n" + "\n".join(lines) + "\n}", s, count=1, flags=re.S)
open(LEVELS, "w").write(s)
print(f"set par for {len(par)} nights")
print("  ".join(f"{k}:{v}" for k, v in items))
