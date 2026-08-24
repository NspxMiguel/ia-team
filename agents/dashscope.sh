# Alibaba Cloud Model Studio (DashScope) — OpenAI-compatible API teammate.
ADAPTER_ID="dashscope"
ADAPTER_LABEL="Alibaba Cloud DashScope"
ADAPTER_KIND="cloud"
ADAPTER_BIN="python3"
ADAPTER_TAGS="code generation, repository understanding, and large refactors"
ADAPTER_INSTALL="key at https://modelstudio.console.alibabacloud.com (API Key), then: pbpaste | claude-autonomous secret import DASHSCOPE_API_KEY"
ADAPTER_KEY_ENV="DASHSCOPE_API_KEY"

CLOUD_BASE_URL="https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
CLOUD_KEY_ENV="DASHSCOPE_API_KEY"
CLOUD_MODEL="qwen3-coder-plus"
CLOUD_ASK_MODEL="qwen3-coder-plus"

. "$TEAM_LIB/cloud.sh"

adapter_probe() { cloud_probe "DASHSCOPE_API_KEY" "qwen3-coder-plus"; }
adapter_ask()   { cloud_ask "$1" "$2" "${3:-}"; }
adapter_run()   { cloud_run "$1" "$2" "${3:-}"; }
