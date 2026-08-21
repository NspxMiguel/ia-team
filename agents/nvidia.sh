# NVIDIA NIM (free tier) — OpenAI-compatible API teammate.
ADAPTER_ID="nvidia"
ADAPTER_LABEL="NVIDIA NIM (free tier)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="reasoning, algorithms, a second architecture opinion"
ADAPTER_INSTALL="free key at https://build.nvidia.com (Get API Key), then: pbpaste | claude-autonomous secret import NVIDIA_API_KEY"
ADAPTER_KEY_ENV="NVIDIA_API_KEY"

CLOUD_BASE_URL="https://integrate.api.nvidia.com/v1"
CLOUD_KEY_ENV="NVIDIA_API_KEY"
CLOUD_MODEL="moonshotai/kimi-k2-thinking"
CLOUD_ASK_MODEL="meta/llama-3.3-70b-instruct"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "NVIDIA_API_KEY" "moonshotai/kimi-k2-thinking"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
