# Mistral (free tier) — OpenAI-compatible API teammate.
ADAPTER_ID="mistral"
ADAPTER_LABEL="Mistral (free tier)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="code completion, European hosting, solid at refactors"
ADAPTER_INSTALL="free key at https://console.mistral.ai/api-keys, then: pbpaste | claude-autonomous secret import MISTRAL_API_KEY"
ADAPTER_KEY_ENV="MISTRAL_API_KEY"

CLOUD_BASE_URL="https://api.mistral.ai/v1"
CLOUD_KEY_ENV="MISTRAL_API_KEY"
CLOUD_MODEL="mistral-large-latest"
CLOUD_ASK_MODEL="mistral-small-latest"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "MISTRAL_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
