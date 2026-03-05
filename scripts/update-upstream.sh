#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🔄 Updating OpenClaw upstream..."

cd openclaw

# 先恢复到干净状态（清除之前应用的补丁，含暂存区），然后拉取最新代码
git reset --hard HEAD 2>/dev/null || true
git pull origin main

# 安装依赖（如果 package.json 有变化）
pnpm install

# 重新构建
pnpm build

cd ..

# 应用 crew skills + addons
./scripts/apply-addons.sh

echo ""
echo "✅ Update complete!"
echo ""
echo "Next steps:"
echo "  1. ./scripts/reinstall-daemon.sh  # 如果有配置变化"
echo "  2. ./scripts/dev.sh gateway       # 启动"
