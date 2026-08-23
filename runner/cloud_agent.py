#!/usr/bin/env python3
"""A small agent loop for any OpenAI-compatible chat API.

This is what lets a plain API model (Groq, NVIDIA, OpenRouter, Cerebras, ...)
act as a teammate instead of a chatbot: it gets file tools and a working
directory, and it works until it reports back.

Standard library only — it has to run on the python3 that ships with macOS.

Exit codes: 0 done, 2 error, 3 quota/rate limit exhausted, 4 timed out,
5 the model no longer exists at the provider.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

QUOTA_MARKS = (
    "rate limit", "rate_limit", "quota", "insufficient_quota", "billing",
    "credits", "too many requests", "usage limit", "out of tokens",
)
DANGEROUS = re.compile(
    r"\b(sudo|rm\s+-rf\s+/|mkfs|shutdown|reboot|:\(\)\{|git\s+push|git\s+reset\s+--hard"
    r"|curl[^|]*\|\s*(ba)?sh|wget[^|]*\|\s*(ba)?sh)\b"
)
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", "dist", "build", ".next"}
MAX_READ = 60_000


def log(msg):
    print(msg, file=sys.stderr, flush=True)


class Workspace:
    """Every path is resolved inside the working directory. No exceptions."""

    def __init__(self, root):
        self.root = os.path.realpath(root)

    def resolve(self, path):
        full = os.path.realpath(os.path.join(self.root, path))
        if full != self.root and not full.startswith(self.root + os.sep):
            raise ValueError("path outside the working directory: %s" % path)
        return full

    def list_files(self, subdir="."):
        base = self.resolve(subdir)
        out = []
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for name in filenames:
                full = os.path.join(dirpath, name)
                try:
                    size = os.path.getsize(full)
                except OSError:
                    continue
                out.append("%s (%d bytes)" % (os.path.relpath(full, self.root), size))
                if len(out) >= 400:
                    out.append("... truncated")
                    return "\n".join(out)
        return "\n".join(out) or "(empty)"

    def read_file(self, path):
        full = self.resolve(path)
        with open(full, "r", encoding="utf-8", errors="replace") as fh:
            data = fh.read(MAX_READ + 1)
        if len(data) > MAX_READ:
            return data[:MAX_READ] + "\n... file truncated"
        return data

    def append_file(self, path, content):
        full = self.resolve(path)
        os.makedirs(os.path.dirname(full) or self.root, exist_ok=True)
        with open(full, "a", encoding="utf-8") as fh:
            fh.write(content)
        return "appended %d bytes to %s" % (len(content), path)

    def write_file(self, path, content):
        full = self.resolve(path)
        os.makedirs(os.path.dirname(full) or self.root, exist_ok=True)
        with open(full, "w", encoding="utf-8") as fh:
            fh.write(content)
        return "wrote %s (%d bytes)" % (path, len(content))

    def edit_file(self, path, find, replace):
        full = self.resolve(path)
        with open(full, "r", encoding="utf-8") as fh:
            data = fh.read()
        hits = data.count(find)
        if hits == 0:
            return "ERROR: the text to replace was not found in %s" % path
        if hits > 1:
            return "ERROR: the text appears %d times in %s — include more context" % (hits, path)
        with open(full, "w", encoding="utf-8") as fh:
            fh.write(data.replace(find, replace))
        return "edited %s" % path

    def run_command(self, command, timeout=120):
        if DANGEROUS.search(command):
            return "ERROR: refused — that command is not allowed here"
        try:
            proc = subprocess.run(
                ["/bin/sh", "-c", command], cwd=self.root, timeout=timeout,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
        except subprocess.TimeoutExpired:
            return "ERROR: command timed out after %ss" % timeout
        out = proc.stdout.decode("utf-8", "replace")
        if len(out) > 12_000:
            out = out[:12_000] + "\n... output truncated"
        return "exit %d\n%s" % (proc.returncode, out)


def tool_schema(readonly):
    tools = [
        {"type": "function", "function": {
            "name": "list_files",
            "description": "List the files in the working directory.",
            "parameters": {"type": "object", "properties": {
                "subdir": {"type": "string", "description": "Optional subdirectory."}}},
        }},
        {"type": "function", "function": {
            "name": "read_file",
            "description": "Read one file.",
            "parameters": {"type": "object", "properties": {
                "path": {"type": "string"}}, "required": ["path"]},
        }},
        {"type": "function", "function": {
            "name": "finish",
            "description": "Report back and stop. Call this when the task is done.",
            "parameters": {"type": "object", "properties": {
                "report": {"type": "string", "description":
                           "What you did, which files, and what you did not do."}},
                "required": ["report"]},
        }},
    ]
    if not readonly:
        tools[2:2] = [
            {"type": "function", "function": {
                "name": "write_file",
                "description": "Create a file or replace its whole content.",
                "parameters": {"type": "object", "properties": {
                    "path": {"type": "string"}, "content": {"type": "string"}},
                    "required": ["path", "content"]},
            }},
            {"type": "function", "function": {
                "name": "append_file",
                "description": "Add text to the end of a file. Use this to write a long file in a few short calls.",
                "parameters": {"type": "object", "properties": {
                    "path": {"type": "string"}, "content": {"type": "string"}},
                    "required": ["path", "content"]},
            }},
            {"type": "function", "function": {
                "name": "edit_file",
                "description": "Replace one unique snippet inside a file.",
                "parameters": {"type": "object", "properties": {
                    "path": {"type": "string"},
                    "find": {"type": "string", "description": "Exact text, unique in the file."},
                    "replace": {"type": "string"}},
                    "required": ["path", "find", "replace"]},
            }},
            {"type": "function", "function": {
                "name": "run_command",
                "description": "Run a shell command in the working directory (tests, build, ls).",
                "parameters": {"type": "object", "properties": {
                    "command": {"type": "string"}}, "required": ["command"]},
            }},
        ]
    return tools


class ModelGone(Exception):
    """O modelo pedido não existe mais no fornecedor.

    Acontece de verdade: a Groq aposentou llama-3.3-70b-versatile e todo cliente
    que a fixava passou a receber 404 em cada chamada. Não é cota, não adianta
    esperar — alguém precisa trocar o nome do modelo.
    """


class TooLarge(Exception):
    """The request no longer fits the provider's per-request budget.

    Free tiers are small: the fix is to carry less history, not to give up.
    """


class ToolCallRejected(Exception):
    """The provider refused the model's tool call (bad JSON, too long).

    Recoverable: tell the model what happened and let it try a smaller step.
    """


class QuotaExhausted(Exception):
    """Out of quota. `retry_after` is set when the API says when to come back."""

    def __init__(self, message, retry_after=0, hard=False):
        Exception.__init__(self, message)
        self.retry_after = retry_after
        self.hard = hard


def parse_retry_after(headers, detail):
    """Seconds to wait, from the header or from the provider's own wording."""
    try:
        value = float(headers.get("retry-after", ""))
        if value > 0:
            return min(value, 120)
    except (TypeError, ValueError):
        pass
    match = re.search(r"try again in\s*([0-9.]+)\s*(ms|s|m)?", detail, re.I)
    if match:
        amount = float(match.group(1))
        unit = (match.group(2) or "s").lower()
        seconds = amount / 1000.0 if unit == "ms" else amount * 60 if unit == "m" else amount
        return min(max(seconds, 1.0), 120)
    return 0


def call_api(base_url, key, model, messages, tools, timeout, temperature):
    body = {"model": model, "messages": messages, "tools": tools,
            "tool_choice": "auto", "temperature": temperature}
    req = urllib.request.Request(
        base_url.rstrip("/") + "/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json",
                 "User-Agent": "ia-team/0.2", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:400]
        low = detail.lower()
        if exc.code == 429:
            # A per-minute rate limit is a queue, not a wall: wait it out.
            # Providers append "upgrade your plan" marketing to both kinds of
            # 429, so the decision rests on whether they told us when to come
            # back — and on the error code, not on the sales pitch.
            retry = parse_retry_after(exc.headers, detail)
            hard = retry == 0 and any(m in low for m in (
                "insufficient_quota", "insufficient quota", "no credit",
                "out of credit", "daily limit", "quota exceeded",
                "exceeded your current quota", "credit balance"))
            raise QuotaExhausted("HTTP 429: %s" % detail, retry, hard)
        if exc.code in (401, 402, 403) and any(m in low for m in QUOTA_MARKS):
            raise QuotaExhausted("HTTP %d: %s" % (exc.code, detail), 0, True)
        if exc.code in (400, 404) and any(m in low for m in (
                "does not exist", "model_not_found", "decommissioned",
                "has been deprecated", "unknown model", "invalid model")):
            raise ModelGone(detail)
        if exc.code == 413 or "request too large" in low or "context length" in low \
                or "too many tokens" in low:
            raise TooLarge(detail)
        if exc.code == 400 and ("tool_use_failed" in low or "tool call" in low):
            raise ToolCallRejected(detail)
        raise RuntimeError("HTTP %d: %s" % (exc.code, detail))
    except urllib.error.URLError as exc:
        raise RuntimeError("network: %s" % exc)


SYSTEM = """You are a member of a software team, working through tools on a real
repository. The working directory is yours; everything you need is there.

Rules of the house:
- Use the tools. Never answer with a patch or a code block as if the human will
  apply it — write the file yourself.
- Read before you write. Match the style, language and conventions already there.
- Stay inside the task. Do not refactor what nobody asked you to.
- Never commit, never push, never touch git history.
- When you are done, call finish with a short report: what you changed, which
  files, and what you deliberately did not do.
- A long file is easier to land in pieces: write_file for the first chunk, then
  append_file for the rest. Huge single calls get rejected by some providers.
Work in small steps and keep going until the task is done."""


def prune(messages, keep):
    """Keep the system prompt, the brief, and the tail of the conversation.

    Tool results pile up fast, and a long history is what pushes a free tier
    over its tokens-per-minute limit. Cutting has to respect one rule: an
    assistant message with tool_calls must keep its tool replies next to it.
    """
    if keep <= 0 or len(messages) <= keep + 2:
        return messages
    head, tail = messages[:2], messages[2:]
    cut = tail[-keep:]
    while cut and cut[0].get("role") == "tool":
        cut = cut[1:]
    return head + cut


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--key-env", required=True)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--brief", required=True)
    ap.add_argument("--mode", choices=["ask", "run"], default="run")
    ap.add_argument("--max-steps", type=int, default=40)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--http-timeout", type=int, default=180)
    ap.add_argument("--temperature", type=float, default=0.2)
    ap.add_argument("--keep", type=int, default=30,
                    help="how many recent messages to carry (0 = everything)")
    ap.add_argument("--max-tool-output", type=int, default=4000,
                    help="how much of a tool result to feed back (free tiers "
                         "have small tokens-per-minute budgets)")
    args = ap.parse_args()

    key = os.environ.get(args.key_env, "")
    if not key:
        log("no %s in the environment" % args.key_env)
        return 2

    with open(args.brief) as fh:
        brief = fh.read()

    ws = Workspace(args.dir)
    readonly = args.mode == "ask"
    tools = tool_schema(readonly)
    messages = [{"role": "system", "content": SYSTEM},
                {"role": "user", "content": brief}]
    deadline = time.time() + args.timeout
    nudges = 0
    seen_calls = {}     # the same call, over and over, means the model is stuck
    wrote_something = False
    keep = args.keep
    calls = {"list_files": lambda a: ws.list_files(a.get("subdir", ".")),
             "read_file": lambda a: ws.read_file(a["path"]),
             "write_file": lambda a: ws.write_file(a["path"], a.get("content", "")),
             "append_file": lambda a: ws.append_file(a["path"], a.get("content", "")),
             "edit_file": lambda a: ws.edit_file(a["path"], a["find"], a.get("replace", "")),
             "run_command": lambda a: ws.run_command(a["command"])}

    for step in range(args.max_steps):
        if time.time() > deadline:
            log("[team] out of time after %d steps" % step)
            return 4
        messages = prune(messages, keep)
        data = None
        for attempt in range(6):
            try:
                data = call_api(args.base_url, key, args.model, messages, tools,
                                args.http_timeout, args.temperature)
                break
            except QuotaExhausted as exc:
                wait = exc.retry_after or (2 ** attempt)
                if exc.hard or attempt == 5 or time.time() + wait > deadline:
                    log("[QUOTA] %s" % exc)
                    return 3
                log("[team] rate limited, waiting %.1fs and carrying on" % wait)
                time.sleep(wait)
            except ModelGone as exc:
                log("[MODELO] %s" % exc)
                return 5
            except TooLarge as exc:
                if keep <= 6:
                    log("[team] the request is too large even with a short history")
                    return 2
                keep = max(6, keep // 2)
                messages = prune(messages, keep)
                log("[team] request too large — carrying %d messages instead" % keep)
            except ToolCallRejected as exc:
                nudges += 1
                if nudges > 4:
                    log("[team] the model kept sending malformed tool calls")
                    return 2
                log("[team] malformed tool call — asking for a smaller step")
                messages.append({"role": "user", "content":
                                 "Your last tool call was rejected by the API "
                                 "(malformed or too large). Send it again as a "
                                 "smaller step: write the file in parts with "
                                 "write_file then append_file, and keep each "
                                 "call short."})
            except RuntimeError as exc:
                log("[team] %s" % exc)
                return 2
        if data is None:
            return 2

        choice = data.get("choices", [{}])[0]
        msg = choice.get("message", {}) or {}
        tool_calls = msg.get("tool_calls") or []
        messages.append({"role": "assistant",
                         "content": msg.get("content") or "",
                         "tool_calls": tool_calls})

        if not tool_calls:
            text = (msg.get("content") or "").strip()
            if text:
                print(text)
                return 0
            messages.append({"role": "user", "content":
                             "Use a tool, or call finish with your report."})
            continue

        for tc in tool_calls:
            fn = tc.get("function", {})
            # Some models prefix the tool name with the namespace they were
            # given it under ("functions.finish"). Same tool.
            name = (fn.get("name", "") or "").split(".")[-1]
            try:
                fargs = json.loads(fn.get("arguments") or "{}")
            except ValueError:
                fargs = {}
            if name == "finish":
                report = fargs.get("report", "").strip() or "(no report)"
                print(report)
                return 0
            signature = name + json.dumps(fargs, sort_keys=True)[:200]
            seen_calls[signature] = seen_calls.get(signature, 0) + 1
            log("  · %s %s" % (name, json.dumps(fargs)[:120]))
            if seen_calls[signature] >= 3:
                messages.append({"role": "tool", "tool_call_id": tc.get("id", ""),
                                 "name": name, "content":
                                 "You already ran this exact call twice and the "
                                 "answer has not changed. Stop looking and do the "
                                 "work: write the file, then call finish."})
                continue
            try:
                result = calls[name](fargs)
            except KeyError:
                result = "ERROR: unknown tool %s" % name
            except Exception as exc:  # a bad path or a missing file is data, not a crash
                result = "ERROR: %s" % exc
            if name in ("write_file", "append_file", "edit_file"):
                wrote_something = True
            messages.append({"role": "tool", "tool_call_id": tc.get("id", ""),
                             "name": name, "content": str(result)[:args.max_tool_output]})

        # Exploring is fine; exploring forever is not.
        if not readonly and not wrote_something and step >= 8 and step % 4 == 0:
            messages.append({"role": "user", "content":
                             "You have spent %d steps looking around without "
                             "changing anything. Start writing now — create or "
                             "edit the file the task asks for, then call finish."
                             % (step + 1)})

    log("[team] hit the step limit (%d)" % args.max_steps)
    return 2


if __name__ == "__main__":
    sys.exit(main())
