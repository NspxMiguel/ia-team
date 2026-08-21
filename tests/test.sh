#!/usr/bin/env bash
# Smoke tests for `team` — everything that does not need a model to answer.
set -u
# No pipefail: `team x | grep -q` kills team with SIGPIPE, which is not a failure.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM="$ROOT/bin/team"
TMP="$(mktemp -d)"
export IA_TEAM_HOME="$TMP/home"
PASS=0; FAIL=0

ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  ✗ %s\n     %s\n' "$1" "${2:-}"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1" "$2"; fi; }

printf 'team tests\n\n'

# --- a repository to play in ------------------------------------------------
REPO="$TMP/repo"; mkdir -p "$REPO"; cd "$REPO"
git init -q .
printf 'hello\n' > a.txt
git add -A; git -c user.email=t@t -c user.name=t commit -qm init

# --- a fake agent: deterministic, no network --------------------------------
mkdir -p "$IA_TEAM_HOME/agents"
cat > "$IA_TEAM_HOME/agents/fake.sh" <<'ADAPTER'
ADAPTER_ID="fake"
ADAPTER_LABEL="Fake agent (tests)"
ADAPTER_BIN="true"
ADAPTER_TAGS="testing"
ADAPTER_INSTALL="nothing to install"
adapter_probe() { echo "ok|fake 1.0"; }
adapter_ask() { echo "the answer is 42"; }
adapter_run() { printf 'b\n' > "$1/b.txt"; printf 'world\n' >> "$1/a.txt"; echo "wrote b.txt and appended to a.txt"; }
ADAPTER
cat > "$IA_TEAM_HOME/agents/broken.sh" <<'ADAPTER'
ADAPTER_ID="broken"
ADAPTER_LABEL="Missing agent (tests)"
ADAPTER_BIN="definitely-not-installed-xyz"
ADAPTER_TAGS="nothing"
ADAPTER_INSTALL="cannot be installed"
adapter_probe() { echo "missing|not installed"; }
adapter_ask() { return 1; }
adapter_run() { return 1; }
ADAPTER

# Adapters shipped in the clone would join the roster; hide them for the test.
TEAM_ISOLATED="$TMP/team"
sed 's|\[ -d "$SELF_DIR/../agents" \]|[ -d "/nonexistent" ]|' "$TEAM" > "$TEAM_ISOLATED"
chmod +x "$TEAM_ISOLATED"

check "doctor runs"                    "$TEAM_ISOLATED doctor"
check "roster lists the fake agent"    "$TEAM_ISOLATED agents | grep -q fake"
check "roster shows a missing agent"   "$TEAM_ISOLATED agents | grep -q broken"
check "help works"                     "$TEAM_ISOLATED help | grep -q 'team run'"
check "unknown command fails"          "! $TEAM_ISOLATED nonsense"
check "run without a task fails"       "! $TEAM_ISOLATED run fake --dir $REPO"
check "run with a missing agent fails" "! $TEAM_ISOLATED run broken --dir $REPO 'x'"

# --- ask --------------------------------------------------------------------
OUT="$("$TEAM_ISOLATED" ask fake --dir "$REPO" "what is it?" 2>&1)"
case "$OUT" in *"42"*) ok "ask returns the answer";; *) bad "ask returns the answer" "$OUT";; esac

# --- run --------------------------------------------------------------------
OUT="$("$TEAM_ISOLATED" run fake --dir "$REPO" "do the thing" 2>&1)"
ID="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
RUN="$IA_TEAM_HOME/runs/$ID"

check "run recorded"                   "[ -d '$RUN' ]"
check "brief written"                  "grep -q 'do the thing' '$RUN/brief.md'"
check "brief carries the agreement"    "grep -q 'do NOT commit' '$RUN/brief.md'"
check "patch captured"                 "[ -s '$RUN/patch.diff' ]"
check "patch has the new file"         "grep -q 'b.txt' '$RUN/patch.diff'"
check "worktree created"               "[ -d '$IA_TEAM_HOME/worktrees/$ID' ]"
check "repo untouched by the run"      "[ ! -f '$REPO/b.txt' ]"
check "show works"                     "$TEAM_ISOLATED show '$ID' | grep -q patch"
check "runs lists it"                  "$TEAM_ISOLATED runs | grep -q '$ID'"

# --- apply / drop -----------------------------------------------------------
check "apply lands the patch"          "$TEAM_ISOLATED apply '$ID' && [ -f '$REPO/b.txt' ]"
check "applied content is right"       "grep -q world '$REPO/a.txt'"
check "drop removes the worktree"      "$TEAM_ISOLATED drop '$ID' && [ ! -d '$IA_TEAM_HOME/worktrees/$ID' ]"
check "drop removes the run"           "[ ! -d '$RUN' ]"
check "branch cleaned up"              "! git -C '$REPO' branch --list 'team/*' | grep -q team"

# --- uncommitted work is carried into the worktree --------------------------
printf 'dirty\n' >> "$REPO/a.txt"
"$TEAM_ISOLATED" run fake --dir "$REPO" "again" >/dev/null 2>&1
ID2="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
check "local changes reach the agent"  "grep -q dirty '$IA_TEAM_HOME/worktrees/$ID2/a.txt'"
"$TEAM_ISOLATED" drop "$ID2" >/dev/null 2>&1

# --- timeout ----------------------------------------------------------------
cat > "$IA_TEAM_HOME/agents/slow.sh" <<'ADAPTER'
ADAPTER_ID="slow"; ADAPTER_LABEL="Slow agent"; ADAPTER_BIN="true"; ADAPTER_TAGS="testing"; ADAPTER_INSTALL="-"
adapter_probe() { echo "ok|slow 1.0"; }
adapter_ask() { sleep 60; }
adapter_run() { sleep 60; }
ADAPTER
START=$(date +%s)
"$TEAM_ISOLATED" ask slow --dir "$REPO" --timeout 3 "hang" >/dev/null 2>&1
ELAPSED=$(( $(date +%s) - START ))
if [ "$ELAPSED" -lt 20 ]; then ok "timeout stops a stuck agent (${ELAPSED}s)"; else bad "timeout stops a stuck agent" "took ${ELAPSED}s"; fi

# --- non-git directory ------------------------------------------------------
PLAIN="$TMP/plain"; mkdir -p "$PLAIN"
OUT="$("$TEAM_ISOLATED" run fake --dir "$PLAIN" "no repo here" 2>&1)"
case "$OUT" in *"not a git repo"*) ok "warns outside a repository";; *) bad "warns outside a repository" "$OUT";; esac

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
rm -rf "$TMP"
[ "$FAIL" -eq 0 ]
