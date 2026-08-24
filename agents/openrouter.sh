# OpenRouter (free models) — OpenAI-compatible API teammate.
ADAPTER_ID="openrouter"
ADAPTER_LABEL="OpenRouter (free models)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="breadth — many vendors behind one key, free models available"
ADAPTER_INSTALL="free key at https://openrouter.ai/keys, then: pbpaste | claude-autonomous secret import OPENROUTER_API_KEY"
ADAPTER_KEY_ENV="OPENROUTER_API_KEY"

CLOUD_BASE_URL="https://openrouter.ai/api/v1"
CLOUD_KEY_ENV="OPENROUTER_API_KEY"
CLOUD_MODEL="z-ai/glm-5.2:free"
CLOUD_ASK_MODEL="nvidia/nemotron-3-super-120b-a12b:free"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "OPENROUTER_API_KEY" "deepseek/deepseek-chat-v3.1:free"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
