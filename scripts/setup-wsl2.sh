#!/bin/bash
# WSL2 环境一键配置脚本

set -e

echo "🔧 Setting up WSL2 environment for OpenClaw for Business..."

# 检查是否在 WSL2 中
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "⚠️  This script is for WSL2 environment only"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 1. 配置 Git 处理行尾符
echo "📝 Configuring Git..."
cd "$PROJECT_ROOT"
git config core.autocrlf input
git config core.eol lf

# 2. 确保脚本有执行权限
echo "🔐 Setting script permissions..."
chmod +x scripts/*.sh

# 3. 检查并安装依赖
echo "📦 Checking dependencies..."

if ! command -v node &> /dev/null; then
  echo "❌ Node.js not found. Please install Node.js first:"
  echo "   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
  echo "   sudo apt-get install -y nodejs"
  exit 1
fi

if ! command -v pnpm &> /dev/null; then
  echo "📦 Installing pnpm..."
  npm install -g pnpm
fi

# 4. 获取 Windows 主机 IP
WSL_HOST=$(ip route show | grep -i default | awk '{ print $3}')

echo ""
echo "✅ WSL2 setup complete!"
echo ""
echo "📌 Important notes:"
echo "   • Access URL: http://${WSL_HOST}:18789"
echo "   • Open this URL in Windows browser"
echo "   • Make sure Windows Firewall allows port 18789"
echo ""
echo "Next steps:"
echo "   1. cd openclaw && pnpm install"
echo "   2. cd .. && ./scripts/dev.sh gateway"
