#!/usr/bin/env bash
# ia-team installer — macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/NspxMiguel/ia-team/main/install.sh | bash
#
# Installs the `team` command, the agent adapters, the API runner, and the
# `team` skill for Claude Code. Nothing is overwritten without a backup first.
set -euo pipefail

REPO="NspxMiguel/ia-team"
RAW="https://raw.githubusercontent.com/$REPO/main"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILL_DIR="$CLAUDE_DIR/skills/team"
TEAM_HOME="${IA_TEAM_HOME:-$HOME/.ia-team}"
BIN_DIR="$HOME/.local/bin"

CLI_ADAPTERS="antigravity claude codex cursor gemini opencode"
API_ADAPTERS="cerebras dashscope deepinfra deepseek fireworks groq hyperbolic lmstudio mistral moonshot nvidia ollama omniroute openai openrouter sambanova together vllm xai zhipu"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required (the worktrees depend on it)."
command -v python3 >/dev/null 2>&1 || die "python3 is required (it runs the API teammates)."

SRC=""
if [ -f "$(dirname "${BASH_SOURCE[0]:-}")/bin/team" ] 2>/dev/null; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

fetch() { # fetch <repo-relative-path> <destination>
  if [ -n "$SRC" ]; then cp "$SRC/$1" "$2"
  else curl -fsSL "$RAW/$1" -o "$2" || die "could not download $1"; fi
}
backup() { [ -e "$1" ] && cp "$1" "$1.bak-$(date +%Y%m%d%H%M%S)" || true; }

say "ia-team"
say "======="
say ""

mkdir -p "$BIN_DIR" "$TEAM_HOME/agents" "$TEAM_HOME/lib" "$TEAM_HOME/runner" \
         "$TEAM_HOME/port" "$SKILL_DIR"

say "-> command in $BIN_DIR"
backup "$BIN_DIR/team"
fetch bin/team "$BIN_DIR/team"
chmod +x "$BIN_DIR/team"

say "-> adapters in $TEAM_HOME/agents"
for a in $CLI_ADAPTERS $API_ADAPTERS; do fetch "agents/$a.sh" "$TEAM_HOME/agents/$a.sh"; done

say "-> runner and libraries"
fetch lib/cloud.sh "$TEAM_HOME/lib/cloud.sh"
fetch lib/port_install.py "$TEAM_HOME/lib/port_install.py"
fetch runner/cloud_agent.py "$TEAM_HOME/runner/cloud_agent.py"
chmod +x "$TEAM_HOME/runner/cloud_agent.py"
fetch port/TEAM.md "$TEAM_HOME/port/TEAM.md"

say "-> the supervisor"
mkdir -p "$TEAM_HOME/bin"
fetch bin/team-watch "$TEAM_HOME/bin/team-watch"
fetch bin/team-models "$TEAM_HOME/bin/team-models"
fetch bin/team-telemetry "$TEAM_HOME/bin/team-telemetry"
fetch lib/quota.py "$TEAM_HOME/lib/quota.py"

say "-> the nudge that starts the sprint on its own"
fetch bin/team-hint "$BIN_DIR/team-hint"
chmod +x "$BIN_DIR/team-hint"
python3 - "$CLAUDE_DIR/settings.json" "$BIN_DIR/team-hint" <<'PY'
import json, os, shutil, sys
caminho, gancho = sys.argv[1], sys.argv[2]
dados = {}
if os.path.exists(caminho):
    shutil.copyfile(caminho, caminho + ".bak-ia-team")
    try:
        dados = json.load(open(caminho))
    except ValueError:
        dados = {}
ganchos = dados.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
# Um gancho só, mesmo reinstalando: procuramos pelo nosso comando antes de somar.
já = any(gancho in json.dumps(entrada) for entrada in ganchos)
if not já:
    ganchos.append({"hooks": [{"type": "command", "command": gancho}]})
    json.dump(dados, open(caminho, "w"), indent=2)
    print("   gancho registrado em " + caminho)
else:
    print("   gancho já estava registrado")
PY

say "-> skill in $SKILL_DIR"
backup "$SKILL_DIR/SKILL.md"
fetch skill/SKILL.md "$SKILL_DIR/SKILL.md"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say ""; say "   note: $BIN_DIR is not on your PATH. Add this to your shell profile:"
     say "     export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# A coleta é opcional e nasce desligada. Perguntamos só quando há alguém no
# terminal: instalação por pipe não tem como responder, e o silêncio ali não
# pode virar um "sim".
if [ -t 0 ]; then
  say ""
  say "Quer ajudar a manter o projeto funcionando?"
  say "O ia-team pode guardar contadores anônimos do que falha aqui — por agente,"
  say "modelo e causa (cota, modelo aposentado, tempo esgotado). Nada de código,"
  say "caminho, briefing ou chave. Fica no seu disco; nada é enviado sozinho."
  printf "Ligar essa coleta? [s/N] "
  read -r resposta || resposta=""
  case "$resposta" in
    s|S|y|Y) python3 "$TEAM_HOME/bin/team-telemetry" --enable >/dev/null 2>&1 && say "   ligada — desligue quando quiser com: team telemetry --disable" ;;
    *) say "   deixando desligada. Se mudar de ideia: team telemetry --enable" ;;
  esac
else
  say ""
  say "Coleta anônima de falhas: desligada. Para ligar: team telemetry --enable"
fi

say ""
"$BIN_DIR/team" doctor || true
say ""
say "Next:"
say "  team hire            free teammates you could still add"
say "  team port            teach Codex/Gemini/opencode to use the team too"
say "  team sprint \"antigravity: the landing page\" \"codex: the API\""
