#!/bin/bash
# OpenClaw for Business - 开发环境启动脚本
# 使用默认存储位置 ~/.openclaw

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_PATH="$HOME/.openclaw/openclaw.json"

# 如果配置文件不存在，从模板创建
if [ ! -f "$CONFIG_PATH" ]; then
  mkdir -p "$HOME/.openclaw"
  echo "📝 Creating default config from template..."
  if [ -f "$PROJECT_ROOT/config-templates/openclaw.json" ]; then
    cp "$PROJECT_ROOT/config-templates/openclaw.json" "$CONFIG_PATH"
  else
    echo "{}" > "$CONFIG_PATH"
  fi
fi

# 安装多 Agent 系统（幂等，已存在的 workspace 不覆盖）
"$PROJECT_ROOT/scripts/setup-crew.sh"

# Apply addons (overrides + patches + skills + agents)
"$PROJECT_ROOT/scripts/apply-addons.sh"

# 检测 WSL2 环境并获取访问地址
if grep -qi microsoft /proc/version 2>/dev/null; then
  WSL_HOST=$(ip route show | grep -i default | awk '{ print $3}')
  ACCESS_URL="http://${WSL_HOST}:18789"
  ENV_NOTE="(WSL2)"
else
  ACCESS_URL="http://127.0.0.1:18789"
  ENV_NOTE=""
fi

echo "🚀 Starting OpenClaw for Business... $ENV_NOTE"
echo "   Data: ~/.openclaw"
echo "   Config: $CONFIG_PATH"
echo "   Access: $ACCESS_URL"
echo ""

cd "$PROJECT_ROOT/openclaw"

# 根据参数决定运行���式
case "${1:-gateway}" in
  gateway)
    shift  # 移除 'gateway' 参数
    # 开发模式：前台运行 + verbose 日志
    pnpm openclaw gateway "$@"
    ;;
  cli)
    shift
    pnpm openclaw "$@"
    ;;
  *)
    pnpm openclaw "$@"
    ;;
esac
