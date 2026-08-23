# ia-team

Put the other AIs on your machine to work as a team — in parallel, talking to
each other — and review what they bring back before it touches your repository.

Claude Code (or whoever runs `team`) stays the lead: it splits the job, writes
the briefs, and reads every diff. Each agent works in a throwaway git worktree,
so nothing lands on your branch until a patch is applied on purpose.

```bash
team sprint "antigravity: the landing page, dark, no framework" \
            "codex: the /api/links route following README.md" \
            "groq: node:test tests for the four routes" \
            "gemini: docs/COMO-USAR.md with curl examples"
```

Four agents, four worktrees, four patches — in the time the slowest one takes.

## Vale a pena? Medido, não achismo

Mesmas duas tarefas de dificuldade média, mesmo enunciado, duas arenas limpas —
três agentes em paralelo contra um só:

| | Três IAs em paralelo | Um agente sozinho |
| --- | --- | --- |
| Tempo de parede | **105 s** | **301 s** |
| Custo em dólar (Anthropic) | **US$ 0,47** | **US$ 1,22** |
| Outros consumos | 22.842 tokens do plano Codex; Groq de graça | — |
| Testes próprios passando | 17 | 14 |

**2,9× mais rápido e 2,6× mais barato**, com a parte mecânica indo para um
modelo gratuito. O caminho até esses números, o que eles não dizem, e quando
*não* vale dividir estão em [docs/EQUIPE-VS-SOLO.md](docs/EQUIPE-VS-SOLO.md).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/NspxMiguel/ia-team/main/install.sh | bash
```

Installs the `team` command in `~/.local/bin`, the adapters and the API runner
in `~/.ia-team`, and a `team` skill for Claude Code in `~/.claude/skills/team`.
Requires `git` and `python3`, nothing else.

## The roster

`team` ships no model of its own. It drives the CLIs already installed, and any
OpenAI-compatible API you have a key for. `team doctor` reports who is actually
available right now.

**Command-line teammates**

| Adapter | Runs | Good at |
| --- | --- | --- |
| `codex` | `codex exec` | Big refactors, backend, following a spec literally |
| `antigravity` | `agy -p` | UI, landing pages, CSS, quick prototypes |
| `gemini` | `gemini -p` | Huge context, long documents, docs |
| `claude` | `claude -p` (Haiku) | A second read of a diff, cheap wide sweeps |
| `opencode` | `opencode run` | Another provider's opinion |
| `cursor` | `cursor-agent -p` | Frontend, edits spread across many files |

`cursor` runs on **`cursor-grok-4.6-high`**, not on `auto`. The `cursor-grok-*`
and `composer-*` families are the ones with the large limits; `auto` picks for
itself and picks expensive, which on a shared account spends someone else's quota.
A model outside those two families is refused before the call — `TEAM_CURSOR_MODEL`
changes the default, `TEAM_CURSOR_ANY_MODEL=1` lifts the guard.

**API teammates** — a small agent loop (`runner/cloud_agent.py`) gives them file
tools, so they edit the repository instead of describing a patch:

| Adapter | Free tier | Good at |
| --- | --- | --- |
| `groq` | yes | Bulk work and tests, answers in seconds |
| `nvidia` | yes | Reasoning, a second architecture opinion |
| `openrouter` | yes | Breadth: many vendors behind one key |
| `cerebras` | yes | The fastest of the lot, repetitive edits |
| `mistral` | yes | Refactors, code completion |
| `together` | free credit | Open models, parallel bulk work |
| `deepseek` | paid, cheap | Hard reasoning, long refactors |

`team hire` prints what is missing and how to get it. Keys are read from the
environment, or from your OS keychain through
[`claude-autonomous secret`](https://github.com/NspxMiguel/claude-autonomous) —
they never pass through the agent's context.

## Commands

```
team doctor                      who is available, signed in, and has quota
team agents                      the roster and what each one is good at
team hire [name]                 how to add someone who is not set up yet
team quota [--clear [agent]]     who is benched, and until when

team run <agent> "task"          one task, isolated worktree, patch out
team sprint "t1" "codex: t2" ... several tasks at once, one agent each
team standup                     who is working right now
team ask <agent> "question"      read-only question
team panel "question"            the same question to everyone, in parallel

team board [n]                   the team's shared notes
team note <author> "text"        leave a note for the next agent
team relay <from> <to> "text"    send one agent a message
team crosscheck <id> [--by x]    have another agent review a patch

team runs | show | diff | apply | drop | wait
team suggest [--force|--mute]    offer to bring more AIs in (asked once)
team port [--global]             teach Codex/Gemini/opencode to use the team too
```

Options for `run`, `sprint`, `ask` and `panel`: `--dir`, `--model`, `--timeout`
(default 900s), `--file` to attach a spec or mockup, `--here` to skip the
worktree, `--bg` to start and keep working.

## How a run works

1. `git worktree add` from `HEAD` into `~/.ia-team/worktrees/<id>`. Uncommitted
   changes are carried over and frozen as a starting commit, so the patch that
   comes back is the agent's work and nothing else.
2. A brief is written: the task, the working agreement (stay here, do not run
   git, match the existing style), the recent board notes, and any message
   addressed to that agent.
3. The agent runs headless under a timeout. `~/.ia-team/runs/<id>` keeps
   `brief.md`, `report.md`, `log.txt`, `patch.diff` and `meta.json`.
4. The report goes on the board, and anything the agent flagged with `TIP:`
   reaches the rest of the team.

Nothing is committed or pushed by an agent — and if one commits inside its own
worktree anyway, the patch is still captured, because the diff is taken against
the starting commit.

## Running out of quota

Free tiers end mid-job. The API runner waits out per-minute rate limits and
carries on; when an agent is genuinely out — credits gone, plan cap hit — it is
benched with a timer and the work is handed to someone else automatically.

```bash
team quota                # who is benched and until when
team quota --clear groq   # put them back early
```

## Working in parallel without stepping on each other

Split by files, not by feelings: two agents in the same file produce two patches
that fight. `team sprint` reports overlapping files when it happens.

Write the contract first — one `team note` with the routes, file names and
signatures — and four agents build against the same interface instead of
inventing four.

## Tests

```bash
tests/test.sh
```

49 checks over the parts that do not need a model: adapters, briefs, worktrees,
patch capture (including from an agent that commits), the board, relays,
sprints, quota benching and hand-off, the once-only suggestion, and porting.

## License

MIT.
