#!/bin/bash
# setup-hrbp.sh - HRBP Agent System 安装脚本
# 将 workspace 模板、共享协议、角色模板部署到 ~/.openclaw/
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$PROJECT_ROOT/config-templates/hrbp-system"
OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"

echo "📦 Setting up HRBP Agent System..."

# ─── 1. 创建 workspace 目录并复制文件 ─────────────────────────
for agent in main hrbp; do
  dest="$OPENCLAW_HOME/workspace-$agent"
  if [ -d "$dest" ]; then
    echo "  ⚠️  workspace-$agent already exists, skipping (use --force to overwrite)"
    if [ "$1" != "--force" ]; then
      continue
    fi
    echo "  🔄 Overwriting workspace-$agent..."
  fi
  mkdir -p "$dest"
  cp "$TEMPLATES/workspaces/$agent/"*.md "$dest/"
  echo "  ✅ workspace-$agent installed"
done

# ─── 2. 复制共享协议到每个 workspace ──────────────────────────
for agent in main hrbp; do
  dest="$OPENCLAW_HOME/workspace-$agent"
  if [ -d "$dest" ]; then
    cp "$TEMPLATES/shared/"*.md "$dest/"
  fi
done
echo "  ✅ Shared protocols (RULES.md, TEMPLATES.md) copied"

# ─── 3. 复制角色模板 ──────────────────────────────────────────
ROLE_DEST="$OPENCLAW_HOME/hrbp-templates"
mkdir -p "$ROLE_DEST"
cp -r "$TEMPLATES/role-templates/"* "$ROLE_DEST/"
echo "  ✅ Role templates installed to $ROLE_DEST"

# ─── 4. 更新 openclaw.json（如果 agents.list 尚未配置） ───────
if [ -f "$CONFIG_PATH" ]; then
  # 检查是否已有 agents.list 配置
  if node -e "
    const c = JSON.parse(require('fs').readFileSync('$CONFIG_PATH','utf8'));
    process.exit(c.agents?.list?.length > 0 ? 0 : 1);
  " 2>/dev/null; then
    echo "  ⚠️  agents.list already configured in openclaw.json, skipping"
  else
    echo "  📝 Merging agent config into openclaw.json..."
    node -e "
      const fs = require('fs');
      const c = JSON.parse(fs.readFileSync('$CONFIG_PATH','utf8'));
      if (!c.agents) c.agents = {};
      c.agents.list = [
        {
          id: 'main',
          default: true,
          name: 'Main Agent',
          workspace: '~/.openclaw/workspace-main',
          subagents: { allowAgents: ['main', 'hrbp'] }
        },
        {
          id: 'hrbp',
          name: 'HRBP',
          workspace: '~/.openclaw/workspace-hrbp'
        }
      ];
      if (!c.bindings) c.bindings = [];
      fs.writeFileSync('$CONFIG_PATH', JSON.stringify(c, null, 2) + '\n');
    "
    echo "  ✅ openclaw.json updated"
  fi
else
  echo "  ⚠️  openclaw.json not found at $CONFIG_PATH"
  echo "     Run ./scripts/dev.sh first to create the config, then re-run this script"
fi

# ─── 5. 完成 ──────────────────────────────────────────────────
echo ""
echo "✅ HRBP Agent System installed!"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.openclaw/openclaw.json — fill in API keys and feishu config"
echo "  2. Start Gateway:  ./scripts/dev.sh gateway"
echo "  3. Start Bridge:   cd bridge && node bridge.mjs"
echo ""
echo "Installed locations:"
echo "  Workspaces:  $OPENCLAW_HOME/workspace-main/, workspace-hrbp/"
echo "  Templates:   $OPENCLAW_HOME/hrbp-templates/"
echo "  Config:      $CONFIG_PATH"
