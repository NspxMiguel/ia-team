#!/usr/bin/env python3
"""team painel — who is working right now, across every AI on this machine.

    team painel            one snapshot
    team painel --watch    refresh every 2 s until Ctrl-C
    team painel --line     one short line (used by the Claude Code status line)
    team painel --test     self-check

Sources, all read-only:
  - Claude Code subagents: ~/.claude/projects/*/*/subagents/agent-*.{meta.json,jsonl}
  - CLI workers started by hand: `codex exec`, `opencode run`, `cursor-agent`, `claude -p`, `gemini`
  - `team run`/`team sprint` runs: ~/.ia-team/runs/*/meta.json
"""
import glob
import json
import os
import re
import subprocess
import sys
import time

CLAUDE = os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude"))
TEAM_HOME = os.environ.get("TEAM_HOME") or os.path.expanduser("~/.ia-team")
# ponytail: "active" = transcript/log written recently; a worker silent for longer
# than this (a long build, say) drops off the panel until it writes again.
ACTIVE_S = 120
STALE_RUN_S = 600

WORKERS = [  # (label, regex over the process command line)
    ("codex", r"\bcodex\b.*\bexec\b"),
    ("opencode", r"\bopencode\b.*\brun\b"),
    ("cursor", r"cursor-agent\b.*\s-p\b|/agent\s+-p\b"),
    ("claude", r"\bclaude\b.*\s(-p|--print)\b"),
    ("gemini", r"\bgemini\b\s+-p\b"),
]


def ago(secs):
    secs = int(secs)
    if secs < 60:
        return f"{secs}s"
    if secs < 3600:
        return f"{secs // 60}m"
    return f"{secs // 3600}h{secs % 3600 // 60:02d}m"


def clip(text, n):
    text = " ".join(str(text).split())
    return text if len(text) <= n else text[: n - 1] + "…"


def subagents(now):
    out = []
    for log in glob.glob(os.path.join(CLAUDE, "projects", "*", "*", "subagents", "agent-*.jsonl")):
        try:
            idle = now - os.path.getmtime(log)
        except OSError:
            continue
        if idle > ACTIVE_S:
            continue
        meta = {}
        try:
            with open(log[: -len(".jsonl")] + ".meta.json") as f:
                meta = json.load(f)
        except (OSError, ValueError):
            pass
        project = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(log))))
        project = project.rsplit("-", 1)[-1] or project
        out.append({
            "who": meta.get("model") or "claude",
            "kind": meta.get("agentType", "subagent"),
            "what": meta.get("description", ""),
            "where": project,
            "idle": idle,
        })
    return out


def processes():
    try:
        ps = subprocess.run(["ps", "-axo", "pid=,etime=,command="], capture_output=True,
                            text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    out = []
    me = os.getpid()
    for line in ps.splitlines():
        parts = line.strip().split(None, 2)
        if len(parts) < 3 or int(parts[0]) == me:
            continue
        pid, etime, cmd = parts
        # --sdk-url / stream-json are the main sessions (the maestro), not workers.
        if "painel.py" in cmd or "--sdk-url" in cmd or re.search(r"\b(grep|rg)\b", cmd.split()[0]):
            continue
        if re.match(r"\S*/?(ba|z|da)?sh\s+(-\w+\s+)*-\w*c\b", cmd):
            continue  # the shell that launched a worker, not the worker
        for label, rx in WORKERS:
            if re.search(rx, cmd):
                model = re.search(r"(?:-m|--model)[ =]([\w.\-/]+)", cmd)
                out.append({"who": label + (f" {model.group(1)}" if model else ""),
                            "kind": f"pid {pid}", "what": cmd, "where": "", "age": etime})
                break
    return out


def team_runs(now):
    out = []
    for meta_path in glob.glob(os.path.join(TEAM_HOME, "runs", "*", "meta.json")):
        try:
            with open(meta_path) as f:
                meta = json.load(f)
        except (OSError, ValueError):
            continue
        if meta.get("status") != "running":
            continue
        log = os.path.join(os.path.dirname(meta_path), "log.txt")
        try:
            idle = now - os.path.getmtime(log if os.path.exists(log) else meta_path)
        except OSError:
            continue
        if idle > STALE_RUN_S:
            continue
        out.append({"who": meta.get("agent", "?") + (f" {meta['model']}" if meta.get("model") else ""),
                    "kind": "team " + meta.get("mode", "run"), "what": meta.get("prompt", ""),
                    "where": os.path.basename(meta.get("root") or meta.get("dir") or ""),
                    "idle": idle})
    return out


def collect():
    now = time.time()
    return subagents(now) + processes() + team_runs(now)


def short_name(who):
    return who.split()[0]


def line(rows):
    if not rows:
        return ""
    counts = {}
    for r in rows:
        k = short_name(r["who"])
        counts[k] = counts.get(k, 0) + 1
    return "⚙ " + " ".join(f"{k}×{n}" if n > 1 else k for k, n in sorted(counts.items()))


def table(rows):
    width = os.get_terminal_size().columns if sys.stdout.isatty() else 120
    if not rows:
        return "painel — nobody is working right now"
    out = [f"painel — {len(rows)} working"]
    for r in rows:
        when = r.get("age") or ago(r.get("idle", 0)) + " ago"
        head = f"  {clip(r['who'], 22):<22} {clip(r['kind'], 16):<16} {clip(r['where'], 14):<14} {when:>9}  "
        out.append(head + clip(r["what"], max(20, width - len(head))))
    return "\n".join(out)


def self_test():
    assert line([]) == ""
    assert line([{"who": "sonnet"}, {"who": "sonnet"}, {"who": "codex gpt-6.1-sol"}]) == "⚙ codex sonnet×2"
    assert clip("a  b\nc", 10) == "a b c" and clip("x" * 30, 5) == "xxxx…"
    assert ago(5) == "5s" and ago(125) == "2m" and ago(3700) == "1h01m"
    assert re.search(WORKERS[0][1], "codex exec -m gpt-6.1-sol 'fix it'")
    assert not re.search(WORKERS[0][1], "vim codex.md")
    assert re.search(WORKERS[3][1], "claude -p 'review this'")
    assert re.match(r"\S*/?(ba|z|da)?sh\s+(-\w+\s+)*-\w*c\b", "/bin/zsh -c codex exec x")
    collect()  # must not raise on this machine
    print("ok")


def main(argv):
    if "--test" in argv:
        return self_test()
    if "--line" in argv:
        print(line(collect()))
        return
    if "--watch" in argv:
        try:
            while True:
                sys.stdout.write("\033[H\033[2J" + table(collect()) + "\n")
                sys.stdout.flush()
                time.sleep(2)
        except KeyboardInterrupt:
            return
    print(table(collect()))


if __name__ == "__main__":
    main(sys.argv[1:])
