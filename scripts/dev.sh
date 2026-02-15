#!/bin/bash
# OpenClaw for Business - 开发环境启动脚本
# 将所有配置和数据存储在项目目录内

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$PROJECT_ROOT/.openclaw-data"

# 创建配置目录
mkdir -p "$DATA_DIR/config"

# 设置环境变量，将 OpenClaw 的所有路径指向项目内
export OPENCLAW_STATE_DIR="$DATA_DIR"
export OPENCLAW_CONFIG_PATH="$DATA_DIR/config/openclaw.json"
export OPENCLAW_OAUTH_DIR="$DATA_DIR/credentials"

# 如果配置文件不存在，从模板创建
if [ ! -f "$OPENCLAW_CONFIG_PATH" ]; then
  echo "📝 Creating default config from template..."
  if [ -f "$PROJECT_ROOT/config-templates/openclaw.json" ]; then
    cp "$PROJECT_ROOT/config-templates/openclaw.json" "$OPENCLAW_CONFIG_PATH"
  else
    echo "{}" > "$OPENCLAW_CONFIG_PATH"
  fi
fi

# 应用补丁（如果有）
if [ -d "patches" ] && [ "$(ls -A patches/*.patch 2>/dev/null)" ]; then
  ./scripts/apply-patches.sh
fi

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
echo "   Data: $DATA_DIR"
echo "   Config: $OPENCLAW_CONFIG_PATH"
echo "   Access: $ACCESS_URL"
echo ""

cd "$PROJECT_ROOT/openclaw"

# 根据参数决定运行模式
case "${1:-gateway}" in
  gateway)
    shift  # 移除 'gateway' 参数
    # 开发模式：前台运行 + verbose 日志
    pnpm openclaw gateway --verbose "$@"
    ;;
  cli)
    shift
    pnpm openclaw "$@"
    ;;
  *)
    pnpm openclaw "$@"
    ;;
esac
