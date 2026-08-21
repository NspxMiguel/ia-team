#!/usr/bin/env python3
"""Write the shared team instructions into each agent's own instruction file.

Existing content is kept: the block lives between markers and is replaced in
place on the next run, so nobody's AGENTS.md gets flattened.
"""
import os
import sys

START, END = "<!-- ia-team:start -->", "<!-- ia-team:end -->"


def install(source, target):
    block = "%s\n%s\n%s\n" % (START, open(source).read().rstrip(), END)
    existing = open(target).read() if os.path.exists(target) else ""
    if START in existing and END in existing:
        out = existing.split(START)[0] + block + existing.split(END, 1)[1]
        how = "updated"
    elif existing.strip():
        out = existing.rstrip() + "\n\n" + block
        how = "appended to"
    else:
        out = block
        how = "wrote"
    os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
    open(target, "w").write(out)
    print("  %s %s" % (how, target))


if __name__ == "__main__":
    for path in sys.argv[2:]:
        install(sys.argv[1], path)
