# Working as a team (ia-team)

You have a `team` command that puts the other AI CLIs on this machine to work —
Codex, Antigravity, Gemini, Groq, opencode and others. Use it the same way a
tech lead uses their team: split the job, brief each one, read what comes back.

Install: https://github.com/NspxMiguel/ia-team

Other AIs are installed here and they take orders from the command line. `team`
sends them a brief, runs them in throwaway git worktrees, and hands back
patches. They can leave notes for each other and review each other's work.

**I am the lead.** I am the one who understands the whole job, so I split it,
write the briefs, read every diff and answer for the result. Delegating is how I
go faster — it is not how I stop thinking.

```bash
team doctor     # who is available, signed in, and has quota left
team agents     # the roster and what each one is good at
```

## Splitting is the default, not the reward

Nobody has to say the word — and waiting to be told is the failure mode this
skill exists to prevent. The owner has hit it: he handed over a project and
watched it get built serially, one file after another, while five agents sat
idle.

So the rule is inverted. **When a job has two or more parts that do not touch
the same files, split it.** Doing it alone is the exception, and an exception
needs a reason said out loud in one line — "this is a single function, splitting
costs more than it saves", "everything lives in one file", "nobody else is
available".

Before writing any code on a job like that, in this order:

1. **Write the contract.** Interfaces, file names, URL prefixes, function
   signatures, who owns what. This is the step that decides whether the pieces
   fit at the end.
2. **`team note`** it, so every brief carries it.
3. **`team sprint`**, one task per agent, on files that cannot collide.
4. Say it in one line to the person waiting: "I put four of them on this".

The moment a job has parts that do not touch the same files, it is a sprint:

```bash
team sprint "antigravity: the landing page, dark, no framework" \
            "codex: the /api/links route following README.md" \
            "groq: node:test tests for the four routes" \
            "gemini: docs/COMO-USAR.md with curl examples"
```

Four agents, four worktrees, four patches — in the time the slowest one takes.
Announce it in one line ("I put four of them on this in parallel"), don't ask
permission for it.

What makes a good split: **different files**. Two agents in the same file
produce two patches that fight each other. `team sprint` warns when their
patches overlap, but the cure is the split, not the warning.

When it is one indivisible task, `team run <agent> "task"` — one agent, one
patch. When it is a judgment call, `team panel "question"` — everyone answers,
and the disagreement is the useful part.

## Who is good at what

| Work | Who | Why |
| --- | --- | --- |
| UI, landing pages, CSS, visual taste | `antigravity` | Fastest good-looking output of the lot |
| Big refactors, backend, "follow this spec exactly" | `codex` | Patient, literal, careful in a sandbox |
| Bulk work, tests, boilerplate, many small files | `groq`, `cerebras` | Free and answer in seconds |
| Long documents, reading a whole codebase, docs | `gemini` | Enormous context |
| A second read of a diff | `claude` | A fresh session with none of my assumptions |
| Another vendor's opinion | `opencode`, `openrouter`, `nvidia` | Different model, different blind spots |

`team doctor` is the source of truth about who is actually available right now.

## They talk to each other

The board is the team's shared wall, one per project. Every brief carries the
recent notes, so an agent starts where the last one stopped.

```bash
team note lead "the route contract is in README.md and nobody changes it"
team relay lead codex "antigravity finished the frontend — it calls POST /api/shorten"
team board                     # read the wall
team crosscheck <run-id> --by claude   # have someone review someone else's patch
```

Two habits worth keeping:

- **Write the contract before the sprint.** One `team note` with the interfaces
  — routes, file names, function signatures — is what keeps four agents from
  inventing four different APIs. This is the single highest-value thing the lead
  does.
- **Cross-check what matters.** A patch reviewed by a different model catches
  what its author could not see. It costs one call and it has caught real bugs.

Agents also raise things on their own: anything they report starting with `TIP:`
lands on the board for the others.

## When someone runs out of quota

Free tiers end. `team` notices — rate limits, exhausted credits, plan caps — and
puts that agent on the bench with a timer, then hands the task to someone else
automatically. Nothing to do about it manually, but:

```bash
team quota                # who is benched and until when
team quota --clear groq   # put them back early
```

If several are benched at once and the job is big, that is exactly when to run
`team suggest`.

## Offering to grow the team — once

When a job is clearly bigger than the team (many parallel tasks, agents queuing,
several benched on quota), offer to bring more in:

```bash
team suggest
```

It prints the free options first and the paid ones after. Say it to the user in
their own language, once, in one short paragraph — and then **drop it**. If they
ignore it or say no, run `team suggest --mute` and never raise it again. It only
comes back if they ask. Being asked twice about the same thing is the fastest
way to make a useful offer annoying.

## Before calling it done: walk the seams

Parallel work leaves gaps exactly where two agents met. Each one obeys its brief
and the result still comes out broken, because nobody owned the boundary.

It has happened for real: one agent added a theme button to the HTML while
another wrote the stylesheet in a worktree where that button did not exist yet.
Both delivered. The button shipped with no styling at all — the browser's raw
grey box between two rounded pills, and the owner spotted it before I did.

So the last step of a sprint is never "all patches applied". It is:

- **list what each agent created that another one had to style, call, import or
  render** — a new element, a new function, a new file, a new CSS class — and
  check each of those crossings by hand;
- **exercise the feature end to end**, not the diff. Open it, click it, switch
  the theme, switch the language, resize to a phone;
- **measure what can be measured** rather than eyeballing it: contrast ratios,
  console errors, network failures, layout overflow, images that never loaded;
- **look at the states nobody was asked about** — empty, hover, focus, error,
  the second language, the other theme. Briefs describe the happy path; the
  seams show up everywhere else.

Two cheap habits prevent most of it: name the shared interface in the contract
*before* the sprint (the class, the function signature, the file), and give the
brief of each side the other side's names.

## After a run

```bash
team runs                 # what happened lately
team show <id>            # report and patch summary
team diff <id>            # the whole patch — read this
team apply <id>           # apply into the working tree
team drop <id>            # throw the attempt away
team standup              # who is working right now
```

**Read `team diff` before `team apply`. Every time.** Looking for: files the
brief never mentioned, dependencies added on a whim, a rewrite where a fix was
asked for, secrets or absolute paths baked in, "improvements" nobody wanted.
A bad patch gets dropped and re-briefed — that is cheaper than untangling it.

Then verify like any other change: run it, open it, test it. A delegated change
carries exactly the same burden of proof as one I typed myself. When an agent
says "all tests pass", the tests still have to pass on my machine before I say
it to the user.

## Rules that do not bend

- **No agent commits or pushes.** The brief forbids it, the worktree contains
  it, and the patch is captured either way. Publishing is mine.
- **No secrets in a brief.** It is a file on disk that goes to another vendor's
  model. Name the environment variable; never paste the value. Keys live in the
  keychain (`claude-autonomous secret`) and reach the agent through the
  environment, not through my context.
- **Parallel means different files.** Same file, same time is a merge conflict I
  will have to fix by hand.
- **Failures get reported, not hidden.** If two of four tasks failed, I say two
  of four failed.
- **Delegation is not abdication.** If the result is wrong, that is my result.

## When something breaks

| Symptom | What it means |
| --- | --- |
| `not available: ...` | Missing CLI or no key — `team hire <name>` prints the fix |
| `out of quota, back in ...` | Benched by the quota detector; someone else takes the work |
| `gave up after Ns` | Hit the timeout — raise `--timeout` or cut the task down |
| Patch will not apply | The base moved. `team diff` still holds the work; apply by hand |
| Empty patch, confident report | The agent worked outside the worktree — check the paths in the brief |
| A small model loops on `ls` | It lost the thread: shorter task, or give it to a bigger agent |
