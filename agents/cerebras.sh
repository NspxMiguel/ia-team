# Cerebras (free tier) — OpenAI-compatible API teammate.
ADAPTER_ID="cerebras"
ADAPTER_LABEL="Cerebras (free tier)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="the fastest of the lot — good for repetitive edits across many files"
ADAPTER_INSTALL="free key at https://cloud.cerebras.ai, then: pbpaste | claude-autonomous secret import CEREBRAS_API_KEY"
ADAPTER_KEY_ENV="CEREBRAS_API_KEY"

CLOUD_BASE_URL="https://api.cerebras.ai/v1"
CLOUD_KEY_ENV="CEREBRAS_API_KEY"
CLOUD_MODEL="qwen-3-coder-480b"
CLOUD_ASK_MODEL="llama-3.3-70b"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "CEREBRAS_API_KEY" "qwen-3-coder-480b"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
