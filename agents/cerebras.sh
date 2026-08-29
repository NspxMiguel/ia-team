# Cerebras (free tier) — OpenAI-compatible API teammate.
ADAPTER_ID="cerebras"
ADAPTER_LABEL="Cerebras (API exige plano pago)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="the fastest of the lot — good for repetitive edits across many files"
ADAPTER_INSTALL="conta em https://cloud.cerebras.ai — atenção: o plano gratuito dá acesso ao Playground, mas a API responde 402 (payment required) até habilitar cobrança. Com a chave: pbpaste | claude-autonomous secret import CEREBRAS_API_KEY"
ADAPTER_KEY_ENV="CEREBRAS_API_KEY"

CLOUD_BASE_URL="https://api.cerebras.ai/v1"
CLOUD_KEY_ENV="CEREBRAS_API_KEY"
CLOUD_MODEL="gpt-oss-120b"
CLOUD_ASK_MODEL="gemma-4-31b"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "CEREBRAS_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
