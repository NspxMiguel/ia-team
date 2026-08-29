# Groq (free tier) — OpenAI-compatible API teammate.
ADAPTER_ID="groq"
ADAPTER_LABEL="Groq (free tier)"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="fast bulk work, tests, boilerplate, refactors on many files — answers in seconds"
ADAPTER_INSTALL="free key at https://console.groq.com/keys, then: pbpaste | claude-autonomous secret import GROQ_API_KEY"
ADAPTER_KEY_ENV="GROQ_API_KEY"

CLOUD_BASE_URL="https://api.groq.com/openai/v1"
CLOUD_KEY_ENV="GROQ_API_KEY"
CLOUD_MODEL="openai/gpt-oss-120b"
CLOUD_ASK_MODEL="openai/gpt-oss-20b"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "GROQ_API_KEY"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
