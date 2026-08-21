# ia-team

Put the other agentic CLIs on your machine to work, and review what they bring
back before it touches your repository.

Claude Code stays the lead: it writes the brief, sends the task to whichever
agent fits, and reads the diff. The other agent works in a throwaway git
worktree, so nothing lands on your branch until the patch is applied on purpose.

```bash
team run antigravity "redo the landing page hero: premium feel, no framework"
team diff antigravity-20260821-132212
team apply antigravity-20260821-132212
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/NspxMiguel/ia-team/main/install.sh | bash
```

Installs three things: the `team` command in `~/.local/bin`, the adapters in
`~/.ia-team/agents`, and a `team` skill for Claude Code in
`~/.claude/skills/team`. Requires `git` and `python3`, nothing else.

## The roster

`team` does not ship a model — it drives whatever is already installed and
signed in. `team doctor` reports the state of each one.

| Adapter | Runs | Good at |
| --- | --- | --- |
| `codex` | `codex exec` | Big refactors, backend, tests, following a spec literally |
| `antigravity` | `agy -p` | UI, landing pages, CSS, quick prototypes |
| `claude` | `claude -p` (Haiku) | A second read of a diff, wide cheap sweeps |
| `opencode` | `opencode run` | A different provider's opinion |
| `cursor` | `cursor-agent -p` | Frontend, edits spread across many files |
| `gemini` | `gemini -p` | Long documents, research |

Adding one more is a file in `~/.ia-team/agents` with four functions —
`adapter_probe`, `adapter_ask`, `adapter_run`, plus its metadata. Copy
`agents/codex.sh` and change the command.

## Commands

```
team doctor                     who is installed and signed in
team agents                     the roster and what each one is good at
team ask <agent> "question"     read-only question — no file is touched
team panel "question"           the same question to everyone, in parallel
team run <agent> "task"         real task in an isolated git worktree
team runs [n]                   recent runs
team show <id>                  brief, report and patch summary
team diff <id>                  the full patch
team apply <id>                 apply the patch to your working tree
team drop <id>                  throw the run and its worktree away
team wait <id>                  block until a --bg run finishes
```

Flags for `ask`, `panel` and `run`: `--dir <path>`, `--model <slug>`,
`--timeout <secs>` (default 900), `--file <path>` to attach a spec or a mockup
(repeatable), `--here` to work in the directory itself, `--bg` to start and
return immediately.

## How a run works

1. `git worktree add` from `HEAD` into `~/.ia-team/worktrees/<id>`, on a
   `team/<agent>/<stamp>` branch. Uncommitted changes are carried over, so the
   agent sees the tree you see.
2. A brief is written: your task, plus the working agreement — stay in the
   directory, do not commit, do not push, match the existing style, report at
   the end.
3. The agent runs headless under a timeout. Everything is kept in
   `~/.ia-team/runs/<id>`: `brief.md`, `log.txt`, `patch.diff`, `meta.json`.
4. `team show` summarises, `team diff` gives you the patch, `team apply` stages
   it in the real repository, `team drop` erases the whole attempt.

Nothing is committed or pushed by an agent. Publishing stays a human decision.

## Costs and limits

Every run spends the quota of the agent you sent it to — `team panel` spends
four at once. Sending two agents at the same files produces two patches that
conflict; parallelism is for disjoint work.

Briefs are plain files on disk that are sent to another vendor's model: point at
secrets by variable name, never paste values.

## Tests

```bash
tests/test.sh
```

Covers the parts that do not need a model: adapter discovery, brief generation,
worktree lifecycle, patch capture, apply and drop.

## License

MIT.
