"""Tunes each night's creature speed ("tempo") toward a target bot win rate.

Target: ~85% in World 1 falling to ~32% in World 20; within a world the
nights step down (+8, +4, 0, -4, -8 points) so the finale is hardest.
Rewrites the TEMPO table in scripts/levels.gd.

Usage: python3 tools/tune_tempo.py <rounds> <tries> [first last]
"""
import os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GODOT = os.environ.get("GODOT", "/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64")
LEVELS = os.path.join(ROOT, "scripts", "levels.gd")
rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 3
tries = int(sys.argv[2]) if len(sys.argv) > 2 else 6
first = int(sys.argv[3]) if len(sys.argv) > 3 else 0
last = int(sys.argv[4]) if len(sys.argv) > 4 else 99


def target(idx):
    w, n = idx // 5, idx % 5
    return 0.85 - w * 0.028 + [0.08, 0.04, 0.0, -0.04, -0.08][n]


def read_tempo():
    s = open(LEVELS).read()
    m = re.search(r"const TEMPO := \{(.*?)\}", s, re.S)
    return {k: float(v) for k, v in re.findall(r'"([\d-]+)": ([\d.]+)', m.group(1))}


def write_tempo(t):
    s = open(LEVELS).read()
    def key(k):
        a, b = k.split("-")
        return int(a) * 10 + int(b)
    items = sorted(t.items(), key=lambda kv: key(kv[0]))
    lines = []
    for i in range(0, len(items), 5):
        lines.append("\t" + ", ".join(f'"{k}": {v:.2f}' for k, v in items[i:i + 5]) + ",")
    body = "{\n" + "\n".join(lines) + "\n}"
    s = re.sub(r"const TEMPO := \{.*?\}", "const TEMPO := " + body, s, count=1, flags=re.S)
    open(LEVELS, "w").write(s)


def run(a, b):
    out = subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tests/bot_test.gd", "--", "range", str(a), str(b), str(tries)],
                         capture_output=True, text=True, timeout=3000).stdout
    res = {}
    for line in out.splitlines():
        m = re.search(r"STAT (\S+) .*?win\s+(\d+)/(\d+)\s+claims\s+(-?\d+)", line)
        if m:
            res[m.group(1)] = (int(m.group(2)) / int(m.group(3)), int(m.group(4)))
    return res


ids = []
for line in open(LEVELS):
    m = re.search(r'\{"id": "([\d-]+)"', line)
    if m:
        ids.append(m.group(1))

for r in range(rounds):
    tempo = read_tempo()
    mid = (first + last) // 2
    with ThreadPoolExecutor(2) as ex:
        parts = list(ex.map(lambda ab: run(*ab), [(first, mid), (mid + 1, last)]))
    res = {**parts[0], **parts[1]}
    changed = 0
    report = []
    for idx in range(first, last + 1):
        lid = ids[idx]
        if lid not in res:
            continue
        rate, claims = res[lid]
        t = tempo.get(lid, 1.0)
        goal = target(idx)
        nt = t
        if rate < goal - 0.17:
            nt = t * (0.78 if rate < goal - 0.4 else 0.88)
        elif rate > goal + 0.17:
            nt = t * (1.15 if rate > goal + 0.4 else 1.07)
        nt = round(min(1.3, max(0.55, nt)), 2)
        if nt != t:
            changed += 1
        tempo[lid] = nt
        report.append(f"{lid}:{rate:.2f}/{goal:.2f}@{t:.2f}")
    write_tempo(tempo)
    print(f"round {r + 1}: changed {changed}")
    print("  ".join(report))
    sys.stdout.flush()
