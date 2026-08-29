# Fireworks AI — OpenAI-compatible API teammate.
ADAPTER_ID="fireworks"
ADAPTER_LABEL="Fireworks AI"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="large coding models, fast inference, and long refactors"
ADAPTER_INSTALL="key at https://app.fireworks.ai/settings/users/api-keys, then: pbpaste | claude-autonomous secret import FIREWORKS_API_KEY"
ADAPTER_KEY_ENV="FIREWORKS_API_KEY"

CLOUD_BASE_URL="https://api.fireworks.ai/inference/v1"
CLOUD_KEY_ENV="FIREWORKS_API_KEY"
CLOUD_MODEL="accounts/fireworks/models/qwen3-coder-480b-a35b-instruct"
CLOUD_ASK_MODEL="accounts/fireworks/models/qwen3-coder-480b-a35b-instruct"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "FIREWORKS_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
