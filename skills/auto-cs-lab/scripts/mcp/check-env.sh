#!/usr/bin/env bash
# 环境检查脚本 — 检查各 MCP 服务器和依赖是否已就绪
# 输出各组件的安装状态，供 Agent 参考决策

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}[已安装]${NC} $name ($cmd)"
        return 0
    else
        echo -e "  ${RED}[未安装]${NC} $name ($cmd)"
        return 1
    fi
}

check_python_package() {
    local name="$1"
    local pkg="$2"
    if pip show "$pkg" &>/dev/null 2>&1 || uvx --help &>/dev/null 2>&1; then
        echo -e "  ${GREEN}[可用]${NC} $name (uvx $pkg)"
        return 0
    else
        echo -e "  ${RED}[不可用]${NC} $name (uvx $pkg)"
        return 1
    fi
}

echo "====================================="
echo "  auto-cs-lab 环境检查"
echo "====================================="
echo ""

echo "--- 基础工具 ---"
check_command "Node.js" "node"
check_command "npm" "npm"
check_command "npx" "npx"
check_command "Python3" "python3"
check_command "pip" "pip"
check_command "uv/uvx" "uv"
check_command "PowerShell" "powershell.exe"
echo ""

echo "--- MCP 服务器 ---"
# 检查 Claude Code MCP 配置
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_LOCAL_SETTINGS="$HOME/.claude/settings.local.json"
CLAUDE_USER_MCP_CONFIG_FILE="$HOME/.claude.json"

check_mcp_in_config() {
    local name="$1"
    local file="$2"
    if [[ -f "$file" ]] && grep -q "\"$name\"" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}[已配置]${NC} $name (在 $(basename $file))"
        return 0
    else
        echo -e "  ${YELLOW}[未配置]${NC} $name"
        return 1
    fi
}



check_mcp() {
    local name="$1"
    check_mcp_in_config "$name" "$CLAUDE_SETTINGS" || \
    check_mcp_in_config "$name" "$CLAUDE_LOCAL_SETTINGS" || \
    check_mcp_in_config "$name" "$CLAUDE_USER_MCP_CONFIG_FILE" || \
    true
}

check_mcp "office-docs"
check_mcp "excel-mcp-server"
check_mcp "powerpoint-mcp-server"
check_mcp "playwright-user"
check_mcp "playwright-isolated"
echo ""

echo "--- Playwright 浏览器 ---"
echo "  [注意] 本脚本仅检查 Chromium，不检查 Firefox/WebKit 等其他 Playwright 浏览器"
if npx @anthropic-ai/playwright-mcp@latest --help &>/dev/null 2>&1; then
    echo -e "  ${GREEN}[就绪]${NC} Playwright MCP"
else
    echo -e "  ${YELLOW}[未就绪]${NC} Playwright MCP — 需要安装: npx @anthropic-ai/playwright-mcp@latest"
fi

# 检查 Chromium 是否安装
CHROMIUM_PATHS=(
    "$HOME/.cache/ms-playwright/chromium-*/chrome-linux/chrome"
    "/ms-playwright/chromium-*/chrome-linux/chrome"
)
CHROMIUM_FOUND=false
for p in "${CHROMIUM_PATHS[@]}"; do
    if ls $p &>/dev/null 2>&1; then
        echo -e "  ${GREEN}[已安装]${NC} Chromium 浏览器"
        CHROMIUM_FOUND=true
        break
    fi
done
if [[ "$CHROMIUM_FOUND" == "false" ]]; then
    echo -e "  ${YELLOW}[未安装]${NC} Chromium 浏览器 — Playwright 需要"
fi
echo ""
echo "  [注意] 本脚本无法识别用户自定义参数启动的 Playwright MCP 配置"
echo "  （如 --browser firefox、自定义 --user-data-dir 等）。如已有自定义配置，请忽略检查结果。"
echo ""

echo "--- uvx 工具可用性 ---"
for pkg in mcp-server-office excel-mcp-server office-powerpoint-mcp-server; do
    if uvx --from "$pkg" --help &>/dev/null 2>&1; then
        echo -e "  ${GREEN}[可用]${NC} uvx --from $pkg"
    else
        echo -e "  ${YELLOW}[未验证]${NC} uvx --from $pkg (首次运行会自动安装)"
    fi
done
echo ""

echo "====================================="
echo "  检查完成"
echo "====================================="
echo ""
echo "提示: 如需安装缺失的 MCP 服务器，运行对应的 scripts/mcp/install-*.sh 脚本"