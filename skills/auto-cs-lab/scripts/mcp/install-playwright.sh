#!/usr/bin/env bash
# 安装 Playwright MCP + Chromium 浏览器
# 幂等: 已安装则跳过

set -euo pipefail

echo "=== 安装 Playwright MCP + Chromium ==="

# 检查是否已配置
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_LOCAL="$HOME/.claude/settings.local.json"

PLAYWRIGHT_CONFIGURED=false

for f in "$CLAUDE_SETTINGS" "$CLAUDE_LOCAL"; do
    if [[ -f "$f" ]] && grep -q "playwright" "$f" 2>/dev/null; then
        echo "Playwright MCP 已在 $(basename $f) 中配置"
        echo "[注意] 本脚本仅通过简单关键词匹配检测，无法识别自定义参数的 Playwright MCP 配置。"
        echo "       如果你已手动配置了 Playwright MCP（如使用了 --browser firefox 或其他参数），"
        echo "       请忽略以下安装步骤，直接跳到 Chromium 检查。"
        PLAYWRIGHT_CONFIGURED=true
        break
    fi
done

if [[ "$PLAYWRIGHT_CONFIGURED" == "true" ]]; then
    echo "Playwright MCP 已配置，跳过 MCP 配置步骤"
else
    # 添加到 Claude Code 配置
    SETTINGS_FILE="$CLAUDE_LOCAL"

    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo '{"mcpServers": {}}' > "$SETTINGS_FILE"
    fi

    echo "添加 Playwright MCP 到 $SETTINGS_FILE ..."

    # 添加 user 模式的 Playwright（用于交互式浏览器操作）
    python3 -c "
import json, sys
with open('$SETTINGS_FILE', 'r') as f:
    config = json.load(f)

if 'mcpServers' not in config:
    config['mcpServers'] = {}

# user 模式 - 用于需要人工确认的浏览器操作
config['mcpServers']['playwright-user'] = {
    'command': 'npx',
    'args': ['@anthropic-ai/playwright-mcp@latest', '--browser', 'chromium', '--user-data-dir', '/tmp/playwright-user'],
    'type': 'stdio'
}

# isolated 模式 - 用于自动化测试截图
config['mcpServers']['playwright-isolated'] = {
    'command': 'npx',
    'args': ['@anthropic-ai/playwright-mcp@latest', '--browser', 'chromium'],
    'type': 'stdio'
}

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print('Playwright MCP 配置已添加')
"
fi

# 安装 Chromium 浏览器
echo "检查 Chromium 浏览器..."
echo "[注意] 本脚本仅检查并安装 Chromium，不处理 Firefox/WebKit 等其他 Playwright 浏览器。"

CHROMIUM_FOUND=false
for p in "$HOME/.cache/ms-playwright/chromium-"*/chrome-linux/chrome \
         "/ms-playwright/chromium-"*/chrome-linux/chrome; do
    if ls $p &>/dev/null 2>&1; then
        echo "Chromium 已安装: $p"
        CHROMIUM_FOUND=true
        break
    fi
done

if [[ "$CHROMIUM_FOUND" == "false" ]]; then
    echo "安装 Chromium 浏览器..."
    npx playwright install chromium
    echo "Chromium 安装完成"
else
    echo "Chromium 已安装，跳过"
fi

echo "Playwright MCP 安装完成！请重启 Claude Code 使配置生效。"
echo ""
echo "[注意] 本脚本安装的是默认 Chromium 配置。如你已有自定义 Playwright MCP 配置"
echo "       （如使用了 --browser firefox 或其他启动参数），请勿重复安装。"