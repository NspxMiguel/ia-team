# Cursor CLI — headless via `cursor-agent -p`.
ADAPTER_ID="cursor"
ADAPTER_LABEL="Cursor CLI (cursor-agent)"
ADAPTER_BIN="cursor-agent"
ADAPTER_TAGS="frontend, React/Next, quick fixes across many files"
ADAPTER_INSTALL="curl https://cursor.com/install -fsS | bash, then: cursor-agent login"

# A conta do Cursor é emprestada, e as famílias Grok e Composer são as que têm
# limite grande — as outras queimam a cota de quem emprestou. Por isso o padrão
# aqui é Grok, e não `auto`: `auto` escolhe sozinho e escolhe caro.
CURSOR_MODELO_PADRAO="${TEAM_CURSOR_MODEL:-cursor-grok-4.6-high}"
CURSOR_MODELOS_PERMITIDOS='^(cursor-grok-|composer-)'

adapter_probe() {
  command -v cursor-agent >/dev/null 2>&1 || { echo "missing|cursor-agent is not installed"; return; }
  if cursor-agent status >/dev/null 2>&1; then
    echo "ok|$(cursor-agent --version 2>/dev/null | head -1) [$CURSOR_MODELO_PADRAO]"
  else
    echo "noauth|not signed in — run: cursor-agent login"
  fi
}

# Sem modelo pedido, entra o padrão. Com modelo pedido fora das duas famílias, a
# chamada para aqui em vez de gastar a cota — a não ser que alguém diga, na
# variável, que sabe o que está fazendo.
_cursor_modelo() {
  local pedido="$1"
  [ -n "$pedido" ] || { echo "$CURSOR_MODELO_PADRAO"; return 0; }
  if [ "${TEAM_CURSOR_ANY_MODEL:-0}" = "1" ] || echo "$pedido" | grep -qE "$CURSOR_MODELOS_PERMITIDOS"; then
    echo "$pedido"; return 0
  fi
  echo "cursor: '$pedido' está fora das famílias de limite grande (cursor-grok-*, composer-*)." >&2
  echo "        Use uma delas, ou TEAM_CURSOR_ANY_MODEL=1 para insistir." >&2
  return 1
}

_cursor() { # _cursor <force?> <dir> <brief> <model>
  local force="$1" dir="$2" brief="$3" model
  model="$(_cursor_modelo "${4:-}")" || return 1
  # --model, não -m: o cursor-agent recusa a forma curta com "unknown option".
  local args=(-p "$(cat "$brief")" --output-format text --model "$model")
  [ "$force" = "write" ] && args+=(--force)
  ( cd "$dir" && cursor-agent "${args[@]}" )
}

adapter_ask() { _cursor read  "$1" "$2" "${3:-}"; }
adapter_run() { _cursor write "$1" "$2" "${3:-}"; }
