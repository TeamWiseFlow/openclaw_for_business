#!/bin/bash
# 重新安装 Gateway Daemon 以更新环境变量
# 支持 macOS (LaunchAgent)、Linux (systemd)、Windows (Task Scheduler)

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$PROJECT_ROOT/.openclaw-data"

export OPENCLAW_STATE_DIR="$DATA_DIR"
export OPENCLAW_CONFIG_PATH="$DATA_DIR/config/openclaw.json"
export OPENCLAW_OAUTH_DIR="$DATA_DIR/credentials"

echo "🔧 Reinstalling Gateway Daemon..."
echo "   Data: $OPENCLAW_STATE_DIR"

# 应用补丁（如果有）
if [ -d "patches" ] && [ "$(ls -A patches/*.patch 2>/dev/null)" ]; then
  ./scripts/apply-patches.sh
fi

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
