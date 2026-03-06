#!/bin/bash
# 重新安装 Gateway Daemon
# 支持 macOS (LaunchAgent)、Linux (systemd)、Windows (Task Scheduler)
# 使用默认存储位置 ~/.openclaw

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "🔧 Reinstalling Gateway Daemon..."
echo "   Data: ~/.openclaw"

# 安装多 Agent 系统（幂等）
"$PROJECT_ROOT/scripts/setup-crew.sh"

# Apply addons (crew skills + 第三方 addon)
"$PROJECT_ROOT/scripts/apply-addons.sh"

cd "$PROJECT_ROOT/openclaw"

# 卸载现有的 daemon
pnpm openclaw daemon uninstall 2>/dev/null || true

# 重新安装（会使用当前环境变量，自动检测操作系统）
pnpm openclaw daemon install

# 检测 WSL2 环境并显示正确的访问地址
if grep -qi microsoft /proc/version 2>/dev/null; then
  WSL_HOST=$(ip route show | grep -i default | awk '{ print $3}')
  ACCESS_URL="http://${WSL_HOST}:18789"
  ENV_NOTE="(从 Windows 浏览器访问)"
else
  ACCESS_URL="http://127.0.0.1:18789"
  ENV_NOTE=""
fi

echo ""
echo "✅ Daemon reinstalled"
echo ""
echo "Now open $ACCESS_URL to use $ENV_NOTE"
