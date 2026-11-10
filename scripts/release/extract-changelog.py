#!/usr/bin/env python3
import sys

if len(sys.argv) < 2:
    sys.exit(1)

ver = sys.argv[1]
try:
    with open("CHANGELOG.md", "r", encoding="utf-8") as f:
        lines = f.readlines()
except FileNotFoundError:
    sys.exit(0)

extracting = False
out = []
for line in lines:
    if line.startswith(f"## [{ver}]"):
        extracting = True
        continue
    if extracting and line.startswith("## ["):
        break
    if extracting:
        out.append(line)

cl = "".join(out).strip()
if cl:
    print(f"## What's Changed in {ver}\n\n{cl}\n")
