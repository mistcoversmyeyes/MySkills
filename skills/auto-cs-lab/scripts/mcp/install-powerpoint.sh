#!/usr/bin/env bash
# 安装 powerpoint-mcp-server — PPT 读写 MCP
# 幂等: 已安装则跳过

set -euo pipefail

SCRIPT_NAME="powerpoint-mcp-server"
echo "=== 安装 $SCRIPT_NAME ==="

# 检查是否已配置
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_LOCAL="$HOME/.claude/settings.local.json"

if [[ -f "$CLAUDE_LOCAL" ]] && grep -q "powerpoint-mcp-server" "$CLAUDE_LOCAL" 2>/dev/null; then
    echo "$SCRIPT_NAME 已在 settings.local.json 中配置，跳过"
    exit 0
fi

if [[ -f "$CLAUDE_SETTINGS" ]] && grep -q "powerpoint-mcp-server" "$CLAUDE_SETTINGS" 2>/dev/null; then
    echo "$SCRIPT_NAME 已在 settings.json 中配置，跳过"
    exit 0
fi

# 确保 uvx 可用
if ! command -v uvx &>/dev/null; then
    echo "错误: uvx 未安装，请先安装 uv (https://docs.astral.sh/uv/)"
    exit 1
fi

# 预下载包
echo "预下载 powerpoint-mcp-server..."
uvx --from office-powerpoint-mcp-server ppt_mcp_server --help &>/dev/null || true

# 添加到 Claude Code 配置
SETTINGS_FILE="$CLAUDE_LOCAL"

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{"mcpServers": {}}' > "$SETTINGS_FILE"
fi

echo "添加 $SCRIPT_NAME 到 $SETTINGS_FILE ..."

python3 -c "
import json, sys
with open('$SETTINGS_FILE', 'r') as f:
    config = json.load(f)

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['powerpoint-mcp-server'] = {
    'command': 'uvx',
    'args': ['--from', 'office-powerpoint-mcp-server', 'ppt_mcp_server'],
    'type': 'stdio'
}

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print('配置已添加')
"

echo "$SCRIPT_NAME 安装完成！请重启 Claude Code 使配置生效。"