# OpenAI — OpenAI-compatible API teammate.
ADAPTER_ID="openai"
ADAPTER_LABEL="OpenAI"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="advanced coding, reasoning, debugging, and architecture"
ADAPTER_INSTALL="key at https://platform.openai.com/api-keys, then: pbpaste | claude-autonomous secret import OPENAI_API_KEY"
ADAPTER_KEY_ENV="OPENAI_API_KEY"

CLOUD_BASE_URL="https://api.openai.com/v1"
CLOUD_KEY_ENV="OPENAI_API_KEY"
CLOUD_MODEL="gpt-5.6"
CLOUD_ASK_MODEL="gpt-5.6"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "OPENAI_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
