#!/usr/bin/env python3
"""Drop from tools/test/fixtures/collision_baseline.json exactly the entries a collision-audit run reports as
"gone (fixed? drop it from the baseline): <area> <check> <id> at [x, y, z]". Every other entry (with its owner and
fix note) is kept as it was.   Usage: tools/audit_collision.sh ... > run.txt; python3 tools/baseline_drop_gone.py run.txt"""
import json, re, sys

P = "tools/test/fixtures/collision_baseline.json"
pat = re.compile(r"gone \(fixed\? drop it from the baseline\): (\S+) (\S+) (.+?) at \[([-\d.]+), ([-\d.]+), ([-\d.]+)\]")
gone = []
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = pat.search(line)
    if m:
        gone.append((m.group(1), m.group(2), m.group(3), [float(m.group(4)), float(m.group(5)), float(m.group(6))]))
raw = open(P, encoding="utf-8", newline="").read()
d = json.loads(raw)
keep, dropped = [], 0
for o in d["offenders"]:
    hit = any(o["area"] == a and o["check"] == c and o["id"] == i and
              sum((x - y) ** 2 for x, y in zip(o["pos"], pos)) ** 0.5 < 0.05 for a, c, i, pos in gone)
    if hit:
        dropped += 1
    else:
        keep.append(o)
d["offenders"] = keep
open(P, "w", encoding="utf-8", newline="").write(json.dumps(d, indent=1, ensure_ascii=False) + ("\n" if raw.endswith("\n") else ""))
print(f"gone lines {len(gone)}, dropped {dropped}, left {len(keep)}")
