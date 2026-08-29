# Hyperbolic — OpenAI-compatible API teammate.
ADAPTER_ID="hyperbolic"
ADAPTER_LABEL="Hyperbolic"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="open coding models, code generation, and repository-scale refactors"
ADAPTER_INSTALL="key at https://app.hyperbolic.xyz/settings, then: pbpaste | claude-autonomous secret import HYPERBOLIC_API_KEY"
ADAPTER_KEY_ENV="HYPERBOLIC_API_KEY"

CLOUD_BASE_URL="https://api.hyperbolic.xyz/v1"
CLOUD_KEY_ENV="HYPERBOLIC_API_KEY"
CLOUD_MODEL="Qwen/Qwen3-Coder-480B-A35B-Instruct"
CLOUD_ASK_MODEL="Qwen/Qwen3-Coder-480B-A35B-Instruct"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "HYPERBOLIC_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
