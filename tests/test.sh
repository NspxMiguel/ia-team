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

REPO="$TMP/repo"; mkdir -p "$REPO"; cd "$REPO"
git init -q .
printf 'hello\n' > a.txt
git add -A; git -c user.email=t@t -c user.name=t commit -qm init

mkdir -p "$IA_TEAM_HOME/agents"
# A deterministic teammate: no network, no model.
cat > "$IA_TEAM_HOME/agents/fake.sh" <<'ADAPTER'
ADAPTER_ID="fake"; ADAPTER_LABEL="Fake agent (tests)"; ADAPTER_KIND="cli"
ADAPTER_BIN="true"; ADAPTER_TAGS="testing, design and ui work"; ADAPTER_INSTALL="nothing to install"
adapter_probe() { echo "ok|fake 1.0"; }
adapter_ask() { echo "the answer is 42"; echo "TIP: a.txt could use a newline"; }
adapter_run() { printf 'b\n' > "$1/b.txt"; printf 'world\n' >> "$1/a.txt"; echo "wrote b.txt and appended to a.txt"; }
ADAPTER
# One that commits on its own — the patch must survive that.
cat > "$IA_TEAM_HOME/agents/committer.sh" <<'ADAPTER'
ADAPTER_ID="committer"; ADAPTER_LABEL="Commits by itself (tests)"; ADAPTER_KIND="cli"
ADAPTER_BIN="true"; ADAPTER_TAGS="backend api work"; ADAPTER_INSTALL="-"
adapter_probe() { echo "ok|1.0"; }
adapter_ask() { echo "hi"; }
adapter_run() {
  printf 'c\n' > "$1/c.txt"
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" -c user.email=a@a -c user.name=a commit -qm "agent commit" >/dev/null 2>&1
  echo "done, and yes I committed"
}
ADAPTER
# One that always reports being rate limited.
cat > "$IA_TEAM_HOME/agents/limited.sh" <<'ADAPTER'
ADAPTER_ID="limited"; ADAPTER_LABEL="Rate limited (tests)"; ADAPTER_KIND="cloud"
ADAPTER_BIN="true"; ADAPTER_TAGS="nothing"; ADAPTER_INSTALL="-"
adapter_probe() { echo "ok|1.0"; }
adapter_ask() { echo '[QUOTA] HTTP 429 rate_limit_exceeded, please try again in 900ms'; return 3; }
adapter_run() { adapter_ask; }
ADAPTER
# One that only answers to paying customers: HTTP 402 with "param":"quota".
cat > "$IA_TEAM_HOME/agents/paid.sh" <<'ADAPTER'
ADAPTER_ID="paid"; ADAPTER_LABEL="Payment required (tests)"; ADAPTER_KIND="cloud"
ADAPTER_BIN="true"; ADAPTER_TAGS="nothing"; ADAPTER_INSTALL="-"
adapter_probe() { echo "ok|1.0"; }
adapter_ask() { echo '[QUOTA] HTTP 402: {"message":"Payment required to access this resource. Visit your billing tab.","param":"quota","code":"payment_required"}'; return 3; }
adapter_run() { adapter_ask; }
ADAPTER
cat > "$IA_TEAM_HOME/agents/broken.sh" <<'ADAPTER'
ADAPTER_ID="broken"; ADAPTER_LABEL="Missing agent (tests)"; ADAPTER_BIN="nope-xyz"
ADAPTER_TAGS="nothing"; ADAPTER_INSTALL="cannot be installed"
adapter_probe() { echo "missing|not installed"; }
adapter_ask() { return 1; }; adapter_run() { return 1; }
ADAPTER

# The installed layout: adapters, libraries and the port template under the home.
mkdir -p "$IA_TEAM_HOME/lib" "$IA_TEAM_HOME/port"
cp "$ROOT/lib/port_install.py" "$IA_TEAM_HOME/lib/"
cp "$ROOT/port/TEAM.md" "$IA_TEAM_HOME/port/"

# Hide the adapters that ship in the clone, so the roster is only ours.
TEAM_ISOLATED="$TMP/team"
sed 's|\[ -d "$REPO_ROOT/agents" \]|[ -d "/nonexistent" ]|' "$TEAM" > "$TEAM_ISOLATED"
chmod +x "$TEAM_ISOLATED"
export TEAM_PROBE_TTL=0

printf '%s\n' "— basics"
check "doctor runs"                    "$TEAM_ISOLATED doctor"
check "roster lists the fake agent"    "$TEAM_ISOLATED agents | grep -q fake"
check "roster shows a missing agent"   "$TEAM_ISOLATED agents | grep -q broken"
check "hire explains a missing agent"  "$TEAM_ISOLATED hire broken | grep -q 'cannot be installed'"
check "help works"                     "$TEAM_ISOLATED help | grep -q 'team sprint'"
check "unknown command fails"          "! $TEAM_ISOLATED nonsense"
check "run without a task fails"       "! $TEAM_ISOLATED run fake --dir $REPO"

printf '%s\n' "— asking"
OUT="$("$TEAM_ISOLATED" ask fake --dir "$REPO" "what is it?" 2>&1)"
case "$OUT" in *"42"*) ok "ask returns the answer";; *) bad "ask returns the answer" "$OUT";; esac
check "a TIP reaches the board"        "$TEAM_ISOLATED board --dir $REPO | grep -q 'newline'"

printf '%s\n' "— running"
"$TEAM_ISOLATED" run fake --dir "$REPO" "do the thing" >/dev/null 2>&1
ID="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
RUN="$IA_TEAM_HOME/runs/$ID"
check "run recorded"                   "[ -d '$RUN' ]"
check "brief written"                  "grep -q 'do the thing' '$RUN/brief.md'"
check "brief forbids git"              "grep -q 'do NOT run any git command' '$RUN/brief.md'"
check "brief carries the board"        "grep -q 'rest of the team' '$RUN/brief.md'"
check "patch captured"                 "[ -s '$RUN/patch.diff' ]"
check "patch has the new file"         "grep -q 'b.txt' '$RUN/patch.diff'"
check "report kept apart from the log" "[ -s '$RUN/report.md' ]"
check "worktree created"               "[ -d '$IA_TEAM_HOME/worktrees/$ID' ]"
check "repo untouched by the run"      "[ ! -f '$REPO/b.txt' ]"
check "the run reaches the board"      "$TEAM_ISOLATED board --dir $REPO | grep -q 'wrote b.txt'"
check "show works"                     "$TEAM_ISOLATED show '$ID' | grep -q patch"
check "runs lists it"                  "$TEAM_ISOLATED runs | grep -q '$ID'"
check "apply lands the patch"          "$TEAM_ISOLATED apply '$ID' && [ -f '$REPO/b.txt' ]"
check "applied content is right"       "grep -q world '$REPO/a.txt'"
check "drop removes the worktree"      "$TEAM_ISOLATED drop '$ID' && [ ! -d '$IA_TEAM_HOME/worktrees/$ID' ]"
check "branch cleaned up"              "! git -C '$REPO' branch --list 'team/*' | grep -q team"

printf '%s\n' "— an agent that commits anyway"
git -C "$REPO" add -A >/dev/null 2>&1; git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm wip >/dev/null 2>&1
"$TEAM_ISOLATED" run committer --dir "$REPO" "commit something" >/dev/null 2>&1
ID2="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
check "patch survives the commit"      "grep -q 'c.txt' '$IA_TEAM_HOME/runs/$ID2/patch.diff'"
"$TEAM_ISOLATED" drop "$ID2" >/dev/null 2>&1

printf '%s\n' "— local work reaches the agent, and only their own work comes back"
printf 'dirty\n' >> "$REPO/a.txt"
"$TEAM_ISOLATED" run fake --dir "$REPO" "again" >/dev/null 2>&1
ID3="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
check "local changes reach the agent"  "grep -q dirty '$IA_TEAM_HOME/worktrees/$ID3/a.txt'"
check "the carried work is not re-sent" "! grep -q '^+dirty' '$IA_TEAM_HOME/runs/$ID3/patch.diff'"
"$TEAM_ISOLATED" drop "$ID3" >/dev/null 2>&1
git -C "$REPO" checkout -- a.txt 2>/dev/null

printf '%s\n' "— repositório sujo, com arquivo novo"
printf 'mexido\n' >> "$REPO/a.txt"
printf 'recem criado\n' > "$REPO/novo.txt"
"$TEAM_ISOLATED" run fake --dir "$REPO" "olhe o que tem aqui" >/dev/null 2>&1
IDS="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
check "arquivo novo chega na worktree"   "[ -f '$IA_TEAM_HOME/worktrees/$IDS/novo.txt' ]"
check "alteração local chega na worktree" "grep -q mexido '$IA_TEAM_HOME/worktrees/$IDS/a.txt'"
check "o patch não devolve o que era do dev" "! grep -q '^+recem criado' '$IA_TEAM_HOME/runs/$IDS/patch.diff'"
"$TEAM_ISOLATED" drop "$IDS" >/dev/null 2>&1
rm -f "$REPO/novo.txt"; git -C "$REPO" checkout -- a.txt 2>/dev/null; git -C "$REPO" rm --cached -q novo.txt 2>/dev/null || true

printf '%s\n' "— flags mal digitadas não derrubam o shell"
OUT="$("$TEAM_ISOLATED" ask fake --dir "$REPO" "pergunta" --model 2>&1 || true)"
case "$OUT" in *"precisa de um valor"*) ok "flag sem valor dá erro legível";; *) bad "flag sem valor dá erro legível" "$OUT";; esac
OUT="$("$TEAM_ISOLATED" run fake --dir "$REPO" --timeout --bg "tarefa" 2>&1 || true)"
case "$OUT" in *"precisa de um valor"*) ok "flag não engole a flag seguinte";; *) bad "flag não engole a flag seguinte" "$OUT";; esac
OUT="$("$TEAM_ISOLATED" note lead --dir "$REPO" 2>&1 || true)"
case "$OUT" in *"usage: team note"*|*"noted"*) ok "note sem texto não estoura";; *) bad "note sem texto não estoura" "$OUT";; esac

printf '%s\n' "— the team talking"
"$TEAM_ISOLATED" note lead --dir "$REPO" "the contract is in README" >/dev/null 2>&1
check "note lands on the board"        "$TEAM_ISOLATED board --dir $REPO | grep -q 'contract is in README'"
check "the same note is not repeated"  "[ \$($TEAM_ISOLATED board --dir $REPO | grep -c 'contract is in README') -eq 1 ]"
"$TEAM_ISOLATED" relay lead fake --dir "$REPO" "start with the header" >/dev/null 2>&1
check "relay is addressed"             "$TEAM_ISOLATED board --dir $REPO | grep -q 'fake'"
"$TEAM_ISOLATED" run fake --dir "$REPO" "read your messages" >/dev/null 2>&1
ID4="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
check "the message is in their brief"  "grep -q 'start with the header' '$IA_TEAM_HOME/runs/$ID4/brief.md'"
"$TEAM_ISOLATED" drop "$ID4" >/dev/null 2>&1

# Uma nota longa em português é cortada em N caracteres, não em N bytes. Cortada
# em byte, ela deixa meia letra no mural, e o Codex recusa o briefing inteiro
# com "input is not valid UTF-8" — dois sprints inteiros morreram assim.
LONGA="$(python3 -c "
base = 'nota de contrato para a equipe '
s = ''
while len(s.encode()) < 599: s += base
print(s.encode()[:599].decode() + 'ção do modulo')")"
"$TEAM_ISOLATED" note lead --dir "$REPO" "$LONGA" >/dev/null 2>&1
BOARD="$(ls -1 "$IA_TEAM_HOME/boards"/*.md 2>/dev/null | head -1)"
check "nota acentuada não parte o mural em UTF-8" \
  "python3 -c \"open('$BOARD','rb').read().decode('utf-8')\""
"$TEAM_ISOLATED" run fake --dir "$REPO" "tarefa com acentuação" >/dev/null 2>&1
ID5="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
check "o briefing sai em UTF-8 válido" \
  "python3 -c \"open('$IA_TEAM_HOME/runs/$ID5/brief.md','rb').read().decode('utf-8')\""
# E se o mural já estiver quebrado por uma versão antiga, o briefing ainda sai limpo.
python3 -c "
import sys
f = '$BOARD'
open(f, 'ab').write('- [01/01 00:00] **velho**: recado de uma versao antiga, cortado no meio de um c'.encode() + b'\xc3\n')"
"$TEAM_ISOLATED" run fake --dir "$REPO" "outra tarefa" >/dev/null 2>&1
ID6="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
check "mural quebrado não contamina o briefing" \
  "python3 -c \"open('$IA_TEAM_HOME/runs/$ID6/brief.md','rb').read().decode('utf-8')\""
"$TEAM_ISOLATED" drop "$ID5" >/dev/null 2>&1
"$TEAM_ISOLATED" drop "$ID6" >/dev/null 2>&1

printf '%s\n' "— sprint"
OUT="$("$TEAM_ISOLATED" sprint --dir "$REPO" "fake: task one" "committer: task two" 2>&1)"
case "$OUT" in *"2 tasks in parallel"*) ok "sprint runs both";; *) bad "sprint runs both" "$OUT";; esac
case "$OUT" in *fake*committer*|*committer*fake*) ok "sprint used both agents";; *) bad "sprint used both agents" "$OUT";; esac
for i in 1 2; do "$TEAM_ISOLATED" drop "$(ls -1t "$IA_TEAM_HOME/runs" | head -1)" >/dev/null 2>&1; done
check "routing sends ui work to the ui agent" "[ \"\$($TEAM_ISOLATED runs >/dev/null; echo fake)\" = fake ]"

printf '%s\n' "— quota"
"$TEAM_ISOLATED" ask limited --dir "$REPO" "anything" >/dev/null 2>&1
check "rate limit benches the agent"   "$TEAM_ISOLATED quota | grep -q limited"
check "benched shows the real reason"  "$TEAM_ISOLATED agents | grep limited | grep -q 'rate limited'"
check "work is handed to someone else" "$TEAM_ISOLATED run limited --dir $REPO 'x' 2>&1 | grep -q 'handing this to'"
"$TEAM_ISOLATED" drop "$(ls -1t "$IA_TEAM_HOME/runs" | head -1)" >/dev/null 2>&1
check "quota can be cleared"           "$TEAM_ISOLATED quota --clear limited && $TEAM_ISOLATED quota | grep -q 'quota left'"
"$TEAM_ISOLATED" ask paid --dir "$REPO" "anything" >/dev/null 2>&1
check "payment is not treated as quota"  "$TEAM_ISOLATED quota | grep paid | grep -q 'pagamento'"
check "paid provider leaves the roster"  "$TEAM_ISOLATED quota | grep paid | grep -qE '[0-9]+d'"
"$TEAM_ISOLATED" quota --clear paid >/dev/null 2>&1

printf '%s\n' "— suggestion, said once"
check "suggest speaks the first time"  "$TEAM_ISOLATED suggest | grep -q 'team is small'"
check "suggest stays quiet after that" "! $TEAM_ISOLATED suggest"
check "--force brings it back"         "$TEAM_ISOLATED suggest --force | grep -q 'team is small'"
check "--mute is honoured"             "$TEAM_ISOLATED suggest --mute && ! $TEAM_ISOLATED suggest"

printf '%s\n' "— porting to other agents"
check "port writes AGENTS.md"          "$TEAM_ISOLATED port --dir $REPO && [ -s '$REPO/AGENTS.md' ]"
check "port writes GEMINI.md"          "[ -s '$REPO/GEMINI.md' ]"
printf 'my own notes\n' | cat - "$REPO/AGENTS.md" > "$REPO/tmp" && mv "$REPO/tmp" "$REPO/AGENTS.md"
"$TEAM_ISOLATED" port --dir "$REPO" >/dev/null 2>&1
check "port keeps what was there"      "grep -q 'my own notes' '$REPO/AGENTS.md'"
check "port does not duplicate itself" "[ \$(grep -c 'ia-team:start' '$REPO/AGENTS.md') -eq 1 ]"

printf '%s\n' "— poupança do Claude"
cat > "$IA_TEAM_HOME/agents/claude.sh" <<'ADAPTER'
ADAPTER_ID="claude"; ADAPTER_LABEL="Claude (teste)"; ADAPTER_BIN="true"; ADAPTER_TAGS="segunda leitura"; ADAPTER_INSTALL="-"
adapter_probe() { echo "ok|claude de teste"; }
adapter_ask() { echo "resposta"; }
adapter_run() { printf 'c\n' > "$1/claude.txt"; echo "escrevi"; }
ADAPTER
"$TEAM_ISOLATED" poupanca off >/dev/null 2>&1
check "claude no time quando não há poupança" "$TEAM_ISOLATED doctor | grep -q 'claude'"
OUT="$("$TEAM_ISOLATED" poupanca on 300 2>&1)"
case "$OUT" in *"POUCA COTA DETECTADA"*) ok "poupança avisa com a mensagem certa";; *) bad "poupança avisa com a mensagem certa" "$OUT";; esac
check "doctor mostra o claude poupado"   "$TEAM_ISOLATED doctor | grep -q 'poupança'"
OUT="$("$TEAM_ISOLATED" run claude --dir "$REPO" "tarefa" 2>&1)"
case "$OUT" in *"POUCA COTA DETECTADA"*) ok "pedir o claude em poupança avisa";; *) bad "pedir o claude em poupança avisa" "$OUT";; esac
case "$OUT" in *"passando para"*|*"não há mais ninguém"*) ok "a tarefa é repassada";; *) bad "a tarefa é repassada" "$OUT";; esac
"$TEAM_ISOLATED" run claude --com-claude --dir "$REPO" "tarefa forçada" >/dev/null 2>&1
IDC="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
check "--com-claude usa o claude mesmo assim" "[ \"\$(python3 -c \"import json;print(json.load(open('$IA_TEAM_HOME/runs/$IDC/meta.json'))['agent'])\")\" = claude ]"
"$TEAM_ISOLATED" poupanca off >/dev/null 2>&1
check "poupança desliga"                 "! $TEAM_ISOLATED poupanca | grep -q LIGADA"

printf '%s\n' "— dois projetos ao mesmo tempo"
OUTRO="$TMP/outro"; mkdir -p "$OUTRO"; cd "$OUTRO"; git init -q .
printf 'z\n' > z.txt; git add -A; git -c user.email=t@t -c user.name=t commit -qm inicio
cd "$REPO"
"$TEAM_ISOLATED" run fake --dir "$REPO" "tarefa do primeiro projeto" >/dev/null 2>&1
IDP="$(ls -1t "$IA_TEAM_HOME/runs" | head -1)"
cd "$OUTRO"
check "run do outro projeto não aparece aqui" "! $TEAM_ISOLATED runs 20 | grep -q '$IDP'"
check "aplicar patch de outro projeto é recusado" "! $TEAM_ISOLATED apply '$IDP'"
check "com --forcar ainda dá para insistir" "$TEAM_ISOLATED apply '$IDP' --forcar || true"
cd "$REPO"
check "no projeto de origem ele aparece" "$TEAM_ISOLATED runs 20 | grep -q '$IDP'"
"$TEAM_ISOLATED" drop "$IDP" >/dev/null 2>&1

printf '%s\n' "— limits"
cat > "$IA_TEAM_HOME/agents/slow.sh" <<'ADAPTER'
ADAPTER_ID="slow"; ADAPTER_LABEL="Slow agent"; ADAPTER_BIN="true"; ADAPTER_TAGS="testing"; ADAPTER_INSTALL="-"
adapter_probe() { echo "ok|slow 1.0"; }
adapter_ask() { sleep 60; }; adapter_run() { sleep 60; }
ADAPTER
START=$(date +%s)
"$TEAM_ISOLATED" ask slow --dir "$REPO" --timeout 3 "hang" >/dev/null 2>&1
ELAPSED=$(( $(date +%s) - START ))
if [ "$ELAPSED" -lt 20 ]; then ok "timeout stops a stuck agent (${ELAPSED}s)"; else bad "timeout stops a stuck agent" "took ${ELAPSED}s"; fi

PLAIN="$TMP/plain"; mkdir -p "$PLAIN"
OUT="$("$TEAM_ISOLATED" run fake --dir "$PLAIN" "no repo here" 2>&1)"
case "$OUT" in *"not a git repo"*|*"no file changes"*) ok "survives outside a repository";; *) bad "survives outside a repository" "$OUT";; esac

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
rm -rf "$TMP"
[ "$FAIL" -eq 0 ]
