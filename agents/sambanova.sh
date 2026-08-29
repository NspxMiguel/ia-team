# SambaNova Cloud — OpenAI-compatible API teammate.
ADAPTER_ID="sambanova"
ADAPTER_LABEL="SambaNova Cloud"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="fast inference, code review, tests, and general-purpose programming"
ADAPTER_INSTALL="key at https://cloud.sambanova.ai/apis, then: pbpaste | claude-autonomous secret import SAMBANOVA_API_KEY"
ADAPTER_KEY_ENV="SAMBANOVA_API_KEY"

CLOUD_BASE_URL="https://api.sambanova.ai/v1"
CLOUD_KEY_ENV="SAMBANOVA_API_KEY"
CLOUD_MODEL="Meta-Llama-3.3-70B-Instruct"
CLOUD_ASK_MODEL="Meta-Llama-3.3-70B-Instruct"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "SAMBANOVA_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
