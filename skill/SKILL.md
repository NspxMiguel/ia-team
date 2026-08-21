---
name: team
description: Hand work to the other agentic CLIs installed on this machine (Codex, Antigravity/agy, opencode, Cursor, Gemini) and review what they bring back, using the `team` command. Use when the user says "manda o codex", "pede pro antigravity fazer", "usa outra IA", "delega isso", "equipe", "segunda opinião", "pergunta pros outros", "paraleliza", "send it to codex", "have antigravity do the design", "ask another AI", "get a second opinion", or when a task splits cleanly — design for one agent, backend for another — and doing it serially would be slower.
---

# Working as a team

Other coding agents are installed here and they take instructions from the
command line. `team` sends them a brief, runs them in an isolated git worktree,
and hands back a patch to review — so their work never lands in the repository
without passing through me first.

**I am the lead, not the router.** I decide what to delegate, write the brief,
read the diff, and answer for the result. A patch I did not read is not work I
delivered.

```bash
team doctor     # who is installed and signed in
team agents     # the roster and what each one is good at
```

## Who gets what

| Work | Send it to | Why |
| --- | --- | --- |
| UI, landing page, CSS, visual polish | `antigravity` | Fast, and the strongest of the three at layout and taste |
| Big refactor, backend, tests, "follow this spec exactly" | `codex` | Patient, literal, stays inside the sandbox |
| A second read of a diff, a wide cheap sweep | `claude` | A fresh session with none of my assumptions, on Haiku |
| Anything, with a different provider's opinion | `opencode` | Free models; slower, use it for breadth |

Not installed here, but supported the moment they are: `cursor`, `gemini`.

**Two agents on the same files at the same time is a merge conflict I have to
resolve by hand.** Parallel runs are for *disjoint* work — one on the CSS, one on
the API. Same file, same time: do it serially.

## The three moves

```bash
team ask <agent> "question"          # read-only, nothing is written
team panel "question"                # the same question to everyone, in parallel
team run <agent> "task"              # real edits, in a throwaway worktree
```

`ask` and `panel` are for judgment — "is this schema sane?", "what breaks if I
delete this?". `panel` is genuinely useful before a decision I cannot easily
undo: three or four independent reads, and the disagreement is the signal.

`run` is for work. It branches from HEAD into `~/.ia-team/worktrees/<id>`,
carries over uncommitted changes so the agent sees the tree I see, and produces
a patch. The repository itself is untouched until I apply it.

Useful flags: `--dir <path>` (default: cwd), `--model <slug>`, `--timeout <secs>`
(default 900), `--file <path>` to attach a mockup or a spec, `--bg` to start and
keep working, `--here` to skip the worktree when the directory is not a repo.

## After a run

```bash
team show <id>     # report + patch summary
team diff <id>     # the whole patch — read this
team apply <id>    # apply into the working tree (staged, ready for review)
team drop <id>     # throw the run and its worktree away
```

**Read `team diff` before `team apply`. Every time.** What I am looking for:
files touched that the brief never mentioned, dependencies added on a whim,
a rewrite where a fix was asked for, secrets or absolute paths baked in,
"improvements" nobody asked for. Reject the run and re-brief rather than
patching someone else's misunderstanding — a second `team run` costs less than
untangling a bad merge.

Then verify like any other change: build it, open it, run the tests. A delegated
change carries exactly the same burden of proof as one I typed myself.

## Writing a brief that works

The agent has no context beyond what I send. A one-line prompt buys a one-line
understanding. Every brief carries:

- **the goal**, in one sentence, in the outcome's terms — "the hero section
  should read as premium without a framework", not "edit index.html";
- **the boundary** — which files it may touch, and what it must not touch;
- **the constraints that already exist** — stack, conventions, "no CDN", the
  language of the interface;
- **what done looks like** — the check I will run against it.

`team` already appends the working agreement (stay in the directory, don't
commit, don't push, match the existing style, report at the end), so I write the
task, not the etiquette.

Attach the artifacts instead of describing them: `--file mockup.png`,
`--file spec.md`, `--file src/theme.css`.

## Rules that do not bend

- **No agent commits or pushes.** The brief forbids it and the worktree contains
  it. Publishing is mine, after review.
- **No secrets in a brief.** It is a plain file on disk and it goes to another
  vendor's model. Point at the env var by name; never paste the value.
- **Nothing runs on the user's main branch.** Worktree by default; `--here` only
  outside a repository or when the user asks for it.
- **A failed or empty run gets reported, not hidden.** `team show` tells the
  truth about what came back; so do I.
- **Delegation is not abdication.** If the result is wrong, that is my result.

## When something breaks

| Symptom | What it means |
| --- | --- |
| `not ready: ...` | The CLI is missing or signed out — `team doctor` prints the fix |
| `gave up after Ns` | Hit the timeout; re-run with a bigger `--timeout` or a smaller task |
| Patch does not apply | The base moved. `team diff <id>` still holds the work; apply it by hand |
| Empty patch, confident report | The agent worked outside the worktree. Check the brief's paths and re-run |
