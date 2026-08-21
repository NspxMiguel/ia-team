# Together AI (free credits) — OpenAI-compatible API teammate.
ADAPTER_ID="together"
ADAPTER_LABEL="Together AI (free credits)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="open models with a generous free credit, good for parallel bulk work"
ADAPTER_INSTALL="free credit at https://api.together.ai/settings/api-keys, then: pbpaste | claude-autonomous secret import TOGETHER_API_KEY"
ADAPTER_KEY_ENV="TOGETHER_API_KEY"

CLOUD_BASE_URL="https://api.together.xyz/v1"
CLOUD_KEY_ENV="TOGETHER_API_KEY"
CLOUD_MODEL="Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8"
CLOUD_ASK_MODEL="meta-llama/Llama-3.3-70B-Instruct-Turbo"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "TOGETHER_API_KEY" "Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
