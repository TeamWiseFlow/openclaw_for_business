#!/bin/bash
# add-agent.sh - 注册新 Agent 到 openclaw.json
# 用法: ./scripts/add-agent.sh <agent-id> [--bind <channel>:<accountId>]
set -e

OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"

usage() {
  echo "Usage: $0 <agent-id> [--bind <channel>:<accountId>]"
  echo ""
  echo "Options:"
  echo "  --bind <channel>:<accountId>  Bind agent to a channel (Mode B direct routing)"
  echo ""
  echo "Examples:"
  echo "  $0 developer"
  echo "  $0 customer-service --bind wechat:wx_xxx"
  exit 1
}

[ -z "$1" ] && usage
AGENT_ID="$1"
shift

BIND_CHANNEL=""
BIND_ACCOUNT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --bind)
      [ -z "$2" ] && { echo "❌ --bind requires <channel>:<accountId>"; exit 1; }
      BIND_CHANNEL="${2%%:*}"
      BIND_ACCOUNT="${2#*:}"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage
      ;;
  esac
done

# 验证 workspace 存在
WORKSPACE="$OPENCLAW_HOME/workspace-$AGENT_ID"
if [ ! -d "$WORKSPACE" ]; then
  echo "❌ Workspace not found: $WORKSPACE"
  echo "   Create the workspace first, then run this script."
  exit 1
fi

# 验证 openclaw.json 存在
if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Config not found: $CONFIG_PATH"
  exit 1
fi

# 检查 agent 是否已存在
if node -e "
  const c = JSON.parse(require('fs').readFileSync('$CONFIG_PATH','utf8'));
  const exists = (c.agents?.list || []).some(a => a.id === '$AGENT_ID');
  process.exit(exists ? 0 : 1);
" 2>/dev/null; then
  echo "❌ Agent '$AGENT_ID' already exists in openclaw.json"
  exit 1
fi

echo "📦 Adding agent: $AGENT_ID"

# 更新 openclaw.json
node -e "
  const fs = require('fs');
  const c = JSON.parse(fs.readFileSync('$CONFIG_PATH','utf8'));

  // 1. 添加到 agents.list
  if (!c.agents) c.agents = {};
  if (!c.agents.list) c.agents.list = [];
  c.agents.list.push({
    id: '$AGENT_ID',
    name: '$AGENT_ID',
    workspace: '~/.openclaw/workspace-$AGENT_ID'
  });

  // 2. 更新 Main Agent 的 allowAgents
  const main = c.agents.list.find(a => a.id === 'main');
  if (main) {
    if (!main.subagents) main.subagents = {};
    if (!main.subagents.allowAgents) main.subagents.allowAgents = [];
    if (!main.subagents.allowAgents.includes('$AGENT_ID')) {
      main.subagents.allowAgents.push('$AGENT_ID');
    }
  }

  // 3. 如果需要绑定渠道
  const bindChannel = '$BIND_CHANNEL';
  const bindAccount = '$BIND_ACCOUNT';
  if (bindChannel) {
    if (!c.bindings) c.bindings = [];
    c.bindings.push({
      agentId: '$AGENT_ID',
      match: { channel: bindChannel, accountId: bindAccount },
      comment: '$AGENT_ID direct channel binding'
    });
  }

  fs.writeFileSync('$CONFIG_PATH', JSON.stringify(c, null, 2) + '\n');
"

echo "  ✅ Added to agents.list"
echo "  ✅ Updated Main Agent allowAgents"

if [ -n "$BIND_CHANNEL" ]; then
  echo "  ✅ Added binding: $BIND_CHANNEL:$BIND_ACCOUNT"
fi

# 更新 Main Agent 的 MEMORY.md（团队花名册）
MAIN_MEMORY="$OPENCLAW_HOME/workspace-main/MEMORY.md"
if [ -f "$MAIN_MEMORY" ]; then
  ROUTE_MODE="spawn"
  [ -n "$BIND_CHANNEL" ] && ROUTE_MODE="both"
  BOUND_CHANNELS="—"
  [ -n "$BIND_CHANNEL" ] && BOUND_CHANNELS="$BIND_CHANNEL"

  # 在花名册表格末尾添加新行
  if grep -q "^| $AGENT_ID " "$MAIN_MEMORY" 2>/dev/null; then
    echo "  ⚠️  Agent already in MEMORY.md roster, skipping"
  else
    sed -i "/^## Notes/i | $AGENT_ID | $AGENT_ID | (update specialty) | $ROUTE_MODE | $BOUND_CHANNELS | active |" "$MAIN_MEMORY"
    echo "  ✅ Updated Main Agent MEMORY.md roster"
  fi
fi

echo ""
echo "✅ Agent '$AGENT_ID' registered successfully!"
echo ""
echo "⚠️  Restart Gateway to apply changes: ./scripts/dev.sh gateway"
